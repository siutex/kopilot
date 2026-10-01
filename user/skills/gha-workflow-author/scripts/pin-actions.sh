#!/usr/bin/env bash
# Pin GitHub Actions `uses:` references to full commit SHAs, keeping the tag as a comment.
#
# Usage: pin-actions [--write] [files...]     default files: every *.yml/*.yaml under .github/
#   owner/repo@v4       -> owner/repo@<sha> # v4
#   owner/repo@LATEST   -> owner/repo@<sha> # <latest release tag>
#   Refs that are already a 40-char SHA, ./local actions and docker:// images are left alone.
# Dry-run by default (prints the plan); --write edits the files in place.
set -euo pipefail

write=0
if [[ "${1:-}" == "--write" ]]; then write=1; shift; fi
command -v gh >/dev/null || { echo "gh CLI required: https://cli.github.com (then: gh auth login)" >&2; exit 1; }

list="$(mktemp)"; trap 'rm -f "$list"' EXIT
if [[ $# -gt 0 ]]; then
  printf '%s\n' "$@" > "$list"
else
  find .github -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | sort > "$list"
fi
[[ -s "$list" ]] || { echo "No workflow files found (run from the repo root or pass files)." >&2; exit 1; }

refs="$(while IFS= read -r f; do
          grep -hoE 'uses:[[:space:]]*[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[A-Za-z0-9_./-]+' "$f" || true
        done < "$list" | sed -E 's/^uses:[[:space:]]*//' | sort -u)"
[[ -n "$refs" ]] || { echo "No remote action references found."; exit 0; }

changed=0; failed=0
while IFS= read -r ref; do
  action="${ref%@*}"; ver="${ref##*@}"
  [[ "$ver" =~ ^[0-9a-f]{40}$ ]] && continue
  repo="$(printf '%s' "$action" | cut -d/ -f1-2)"
  tag="$ver"
  if [[ "$ver" == "LATEST" ]]; then
    tag="$(gh api "repos/$repo/releases/latest" -q .tag_name 2>/dev/null || true)"
    [[ -n "$tag" ]] || tag="$(gh api "repos/$repo/tags" -q '.[0].name' 2>/dev/null || true)"
    [[ -n "$tag" ]] || { echo "WARN  $ref: cannot find a release or tag" >&2; failed=$((failed + 1)); continue; }
  fi
  sha="$(gh api "repos/$repo/commits/$tag" -q .sha 2>/dev/null || true)"
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { echo "WARN  $ref: cannot resolve '$tag' to a commit (typo, private repo, or API rate limit?)" >&2; failed=$((failed + 1)); continue; }
  echo "PIN   $action@$ver  ->  $action@$sha # $tag"
  changed=$((changed + 1))
  if [[ $write -eq 1 ]]; then
    while IFS= read -r f; do
      A="$action" V="$ver" S="$sha" T="$tag" perl -i -pe \
        's{(uses:\s*)\Q$ENV{A}\E\@\Q$ENV{V}\E(?=\s|$)[ \t]*(#.*)?$}{$1$ENV{A}\@$ENV{S} # $ENV{T}}' "$f"
    done < "$list"
  fi
done <<< "$refs"

[[ $failed -gt 0 ]] && echo "$failed reference(s) could not be resolved (see WARN lines)."
if [[ $changed -eq 0 && $failed -eq 0 ]]; then echo "Everything is already pinned."
elif [[ $changed -eq 0 ]]; then :
elif [[ $write -eq 0 ]]; then echo "Dry run. Re-run with --write to apply."
else echo "Pinned $changed reference(s). Review with: git diff"; fi
