#!/usr/bin/env bash
# Compact Terraform plan summary for human or LLM review. Prints attribute NAMES only, never values.
#
# Usage: tf-plan-summary <plan.out | plan.json | plan.log>
#   plan.out  binary plan from `terraform plan -out=plan.out` (run from the same, initialised root module)
#   plan.json output of `terraform show -json plan.out`
#   plan.log  text plan output, e.g. copied from a CI job log
# Markers: "!!" = delete/replace of a stateful resource, " !" = IAM / network access change.
# Env: MAX_ROWS (default 80) caps the number of resource lines printed.
set -euo pipefail

in="${1:-}"
MAX_ROWS="${MAX_ROWS:-80}"
if [[ -z "$in" || ! -f "$in" ]]; then
  echo "usage: tf-plan-summary <plan.out|plan.json|plan.log>" >&2
  echo "create a plan first:  terraform plan -out=plan.out" >&2
  exit 2
fi

summarize_json() {
  jq -r --argjson max "$MAX_ROWS" '
    def act:
      (.change.actions) as $a
      | if   $a == ["delete","create"] or $a == ["create","delete"] then "REPLACE"
        elif $a == ["delete"] then "DELETE"
        elif $a == ["create"] then "create"
        elif $a == ["update"] then "update"
        else "other" end;
    def risky: test("db|rds|sql|database|cosmos|dynamo|bucket|storage|disk|volume|efs|filestore|kms|key_vault|keyring|crypto|dns|zone|record|secret|queue|topic|sns|sqs|pubsub|cluster|redis|elasticache|cache|backup|vault"; "i");
    def access: test("iam|policy|role|security_group|firewall|network_acl|nsg|permission|binding|member|access"; "i");
    def changed_keys:
      (.change.before // {}) as $b | (.change.after // {}) as $a | (.change.after_unknown // {}) as $u
      | [ (($a|keys) + ($b|keys)) | unique[] | select($b[.] != $a[.] or ($u[.] // false) == true) ];
    def paths: [ (.change.replace_paths // [])[] | map(tostring) | join(".") ] | unique;

    [ .resource_changes[]? | select(act != "other") | . + {a: act} ] as $rc
    | ($rc | map(select(.a == "create")) | length) as $c
    | ($rc | map(select(.a == "update")) | length) as $u
    | ($rc | map(select(.a == "REPLACE")) | length) as $r
    | ($rc | map(select(.a == "DELETE")) | length) as $d
    | "Plan: \($c) create, \($u) update, \($r) REPLACE, \($d) DELETE",
      ( [ .resource_drift[]? ] | length | select(. > 0) | "Drift detected outside Terraform: \(.) resource(s)" ),
      ( [ .resource_drift[]? | "  drift: \(.address)" ] | .[:20][] ),
      ( [ .output_changes // {} | to_entries[] | select(.value.actions != ["no-op"]) | .key ]
          | select(length > 0) | "Outputs changing: \(join(", "))" ),
      "---",
      ( $rc
        | sort_by([ ({"DELETE":0,"REPLACE":1,"update":2,"create":3}[.a]), .address ])
        | .[:$max][]
        | (if (.a == "DELETE" or .a == "REPLACE") and (.type | risky) then "!! "
           elif (.type | access) then " ! " else "   " end)
          + "\(.a) \(.address)"
          + ( if .a == "update" then "  changed: " + (changed_keys | .[:12] | join(", "))
              elif .a == "REPLACE" then "  replace: " + (paths | if length == 0 then "(forced, e.g. -replace or taint)" else join(", ") end)
              else "" end )
          + ( if .action_reason then "  [" + .action_reason + "]" else "" end ) ),
      ( $rc | length | select(. > $max) | "... \(. - $max) more rows (raise MAX_ROWS to see them)" )
  '
}

first="$(head -c 2 "$in" | od -An -c | tr -d ' \n')"
if [[ "$first" == "PK" ]]; then
  # Binary plan files are zip archives; decoding needs the initialised root module it was created in.
  terraform show -json "$in" | summarize_json
elif jq -e 'has("resource_changes") or has("format_version")' "$in" >/dev/null 2>&1; then
  summarize_json < "$in"
else
  # Text log (e.g. from CI): keep only the resource header lines and the totals.
  perl -ne '
    s/\e\[[0-9;]*[A-Za-z]//g; s/\r//g;
    s/^\S+\t\S+\t//; s/^\d{4}-\d\d-\d\dT[\d:.]+Z ?//;   # strip gh log prefixes / timestamps
    if (/^\s*# (\S+) (will be|must be|has been) (.*)$/) {
      my ($addr, $what) = ($1, $3);
      my $tag = $what =~ /destroyed/ && $what !~ /created/ ? "DELETE"
              : $what =~ /replaced/ ? "REPLACE"
              : $what =~ /created/ ? "create"
              : $what =~ /updated/ ? "update"
              : $what =~ /read/ ? "read" : $what;
      next if $tag eq "read";
      print "$tag $addr\n";
    } elsif (/^(Plan:|No changes|Changes to Outputs|Error:|Warning:)/) { print; }
  ' "$in" | awk -v max="$MAX_ROWS" 'NR<=max {print} NR==max+1 {print "... truncated (raise MAX_ROWS)"}'
fi
