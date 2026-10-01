#!/usr/bin/env bash
# Compact failure excerpt for a GitHub Actions run, for human or LLM triage.
#
# Usage: gha-failed-log                       latest failed run on the current git branch
#        gha-failed-log <run-id | run-url>    a specific run
#        gha-failed-log --file <saved.log>    trim a log you already saved (gh run view --log-failed > saved.log)
# Env:   MAX_LINES (default 120) total output cap, CONTEXT (default 3) lines around each error, TAIL (default 15) last lines kept per step
set -euo pipefail
MAX_LINES="${MAX_LINES:-120}"; CONTEXT="${CONTEXT:-3}"; TAIL="${TAIL:-15}"

trim() {
  perl -e '
    use strict; use warnings;
    my ($ctx, $max, $tail) = @ARGV;
    my $err = qr/(##\[error\]|\bERR!|Error:|\b(errors?|fail|failed|failure|fatal|denied|forbidden|unauthori[sz]ed|not found|cannot|could not|unable to|exit code|exited with|timed out|panic|exception|traceback|no space left|killed|out of memory|AccessDenied|Not authorized)\b)/i;
    my (@segs, %idx);
    while (my $line = <STDIN>) {
      $line =~ s/\e\[[0-9;]*[A-Za-z]//g; $line =~ s/\r//g; chomp $line;
      my @f = split /\t/, $line, 3;
      my ($hdr, $text) = @f == 3 ? ("$f[0] > $f[1]", $f[2]) : ("", $line);
      $text =~ s/^\x{FEFF}?\d{4}-\d\d-\d\dT[\d:.]+Z ?//;
      next if $text =~ /^\s*$/ || $text =~ /^##\[(group|endgroup)\]/;
      $text = substr($text, 0, 300) . " ..." if length($text) > 300;
      if (!exists $idx{$hdr}) { push @segs, { hdr => $hdr, lines => [] }; $idx{$hdr} = $#segs; }
      push @{ $segs[$idx{$hdr}]{lines} }, $text;
    }
    my @out;
    for my $s (@segs) {
      my @L = @{ $s->{lines} }; my $n = @L; next unless $n;
      my (%k, $hits);
      for my $i (0 .. $#L) {
        next unless $L[$i] =~ $err;
        $hits++;
        $k{$_} = 1 for grep { $_ >= 0 && $_ < $n } ($i - $ctx) .. ($i + $ctx);
      }
      my $t = $hits ? $tail : ($tail < 5 ? $tail : 5);   # quiet steps get a short tail
      $k{$_} = 1 for grep { $_ >= 0 } ($n - $t) .. ($n - 1);
      push @out, "== $s->{hdr} ==" if $s->{hdr} ne "";
      my ($prev, $last) = (-1, "");
      for my $i (sort { $a <=> $b } keys %k) {
        push @out, "   [... " . ($i - $prev - 1) . " lines skipped]" if $i > $prev + 1;
        push @out, $L[$i] unless $L[$i] eq $last;
        ($prev, $last) = ($i, $L[$i]);
      }
    }
    if (@out > $max) {
      my $head = int($max * 0.3); my $tl = $max - $head; my $om = @out - $max;
      @out = (@out[0 .. $head - 1], "   [... $om lines omitted, raise MAX_LINES for more]", @out[-$tl .. -1]);
    }
    print "(no log lines; logs may have expired or the run was cancelled)\n" unless @out;
    print "$_\n" for @out;
  ' "$CONTEXT" "$MAX_LINES" "$TAIL"
}

if [[ "${1:-}" == "--file" ]]; then
  [[ -f "${2:-}" ]] || { echo "usage: gha-failed-log --file <saved.log>" >&2; exit 2; }
  trim < "$2"; exit 0
fi

command -v gh >/dev/null || { echo "gh CLI required: https://cli.github.com (then: gh auth login)" >&2; exit 1; }

arg="${1:-}"; repo=""
if [[ "$arg" =~ github\.com/([^/]+/[^/]+)/actions/runs/([0-9]+) ]]; then
  repo="${BASH_REMATCH[1]}"; run="${BASH_REMATCH[2]}"
elif [[ "$arg" =~ ^[0-9]+$ ]]; then
  run="$arg"
else
  branch="$(git branch --show-current 2>/dev/null || true)"
  if [[ -n "$branch" ]]; then
    run="$(gh run list --branch "$branch" --status failure --limit 1 --json databaseId -q '.[0].databaseId')"
  else
    run="$(gh run list --status failure --limit 1 --json databaseId -q '.[0].databaseId')"
  fi
  [[ -n "$run" ]] || { echo "No failed runs found${branch:+ on branch $branch}." >&2; exit 1; }
fi

ghr() { if [[ -n "$repo" ]]; then gh "$@" -R "$repo"; else gh "$@"; fi; }

ghr run view "$run" --json workflowName,displayTitle,event,headBranch,headSha,conclusion,url,jobs -q '
  "Run: \(.workflowName) | \(.displayTitle)",
  "Event: \(.event)  Branch: \(.headBranch)  SHA: \(.headSha[0:7])  Result: \(.conclusion)",
  "URL: \(.url)",
  "Failed steps:",
  (.jobs[] | select(.conclusion == "failure") | .name as $j
     | ([.steps[]? | select(.conclusion == "failure") | "  - \($j) > \(.name)"] | if length == 0 then ["  - \($j) (job-level failure: timeout, cancelled, or runner lost)"] else . end)[])'
echo "--- log excerpt ---"
ghr run view "$run" --log-failed 2>/dev/null | trim
