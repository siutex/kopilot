#!/usr/bin/env bash
# Compact npm vulnerability + outdated summary for human or LLM triage. Run in the package root.
#
# Usage: npm-audit-summary
# Env:   MIN_SEVERITY=low|moderate|high|critical (default moderate)
#        INCLUDE_DEV=1      include devDependencies (default: production deps only)
#        SKIP_OUTDATED=1    skip the `npm outdated` section
#        MAX_ROWS (default 40) cap per section
set -euo pipefail
command -v jq >/dev/null || { echo "jq required" >&2; exit 1; }
[[ -f package.json ]] || { echo "Run from a directory containing package.json" >&2; exit 1; }

min="${MIN_SEVERITY:-moderate}"; max="${MAX_ROWS:-40}"
omit="--omit=dev"; scope="prod deps"
if [[ "${INCLUDE_DEV:-}" == 1 ]]; then omit=""; scope="all deps"; fi

echo "node $(node -v 2>/dev/null || echo '?') | npm $(npm -v 2>/dev/null || echo '?') | scope: $scope | min severity: $min"
[[ -f package-lock.json ]] || echo "NOTE: no package-lock.json (npm audit needs one: npm install --package-lock-only)"

echo "--- vulnerabilities ---"
audit="$(npm audit --json $omit 2>/dev/null || true)"
if [[ -z "$audit" ]] || ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$audit"; then
  echo "npm audit produced no JSON (offline, private registry without audit support, or missing lockfile)."
else
  jq -r --arg min "$min" --argjson max "$max" '
    def rank: {"info":0,"low":1,"moderate":2,"high":3,"critical":4}[.] // 0;
    def fix: if type == "object" then "\(.name)@\(.version)\(if .isSemVerMajor then " (MAJOR)" else "" end)"
             elif . == true then "npm audit fix" else "none" end;
    def advisories: [ .via[] | if type == "object"
                        then (.title // "advisory") + (if .url then " " + (.url | split("/") | last) else "" end)
                        else "via " + . end ] | unique | join("; ") | .[0:180];
    if .error then "npm audit error: \(.error.summary // .error)"
    else
      (.metadata.vulnerabilities // {} | "Totals: critical=\(.critical // 0) high=\(.high // 0) moderate=\(.moderate // 0) low=\(.low // 0)"),
      ( [ .vulnerabilities // {} | .[] | select((.severity | rank) >= ($min | rank)) ]
        | sort_by([ -(.severity | rank), .name ]) as $v
        | if ($v | length) == 0 then "Nothing at or above \($min)."
          else ( $v[:$max][]
                 | "\(.severity | ascii_upcase) \(.name) [\(if .isDirect then "direct" else "transitive" end)] fix=\(.fixAvailable | fix) :: \(advisories)" ),
               ( $v | length | select(. > $max) | "... \(. - $max) more (raise MAX_ROWS)" )
          end )
    end' <<<"$audit"
fi

if [[ "${SKIP_OUTDATED:-}" != 1 ]]; then
  echo "--- outdated (direct deps) ---"
  out="$(npm outdated --json 2>/dev/null || true)"
  if [[ -z "$out" ]] || ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$out"; then
    echo "All direct dependencies are up to date (or npm outdated failed)."
  else
    jq -r --argjson max "$max" '
      def major: tostring | split(".")[0];
      [ to_entries[] | { name: .key, v: (.value | if type == "array" then .[0] else . end) } ] as $all
      | if ($all | length) == 0 then "All direct dependencies are up to date."
        else ( $all | sort_by(.name) | .[:$max][]
               | (.v.current // "not-installed") as $c
               | "\(.name) \($c) -> wanted \(.v.wanted // "?") latest \(.v.latest // "?")"
                 + (if $c == "not-installed" then " [NOT INSTALLED]"
                    elif ($c | major) != ((.v.latest // $c) | major) then " [MAJOR]" else "" end) ),
             ( $all | length | select(. > $max) | "... \(. - $max) more (raise MAX_ROWS)" )
        end' <<<"$out"
  fi
fi
