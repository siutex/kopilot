#!/usr/bin/env bash
# Install the Copilot SRE kit.
#   ./install.sh user          skills + SRE Triage agent into ~/.copilot (available in every workspace),
#                              plus the summary scripts as commands in ~/.local/bin
#   ./install.sh repo <path>   always-on + path-scoped instruction files into a repository's .github/
# Existing files are never overwritten; the script tells you what it skipped.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

copy_safe() {  # copy_safe <src> <dst>
  if [[ -e "$2" ]]; then echo "  skip (exists): $2"; else cp "$1" "$2"; echo "  added: $2"; fi
}

case "${1:-}" in
  user)
    echo "Skills -> ~/.copilot/skills"
    for dir in "$here"/user/skills/*/; do
      name="$(basename "$dir")"
      if [[ -e "$HOME/.copilot/skills/$name" ]]; then
        echo "  skip (exists): ~/.copilot/skills/$name  (delete it first to reinstall)"
      else
        mkdir -p "$HOME/.copilot/skills"
        cp -R "$dir" "$HOME/.copilot/skills/$name"
        echo "  added: ~/.copilot/skills/$name"
      fi
    done
    find "$HOME/.copilot/skills" -path '*/scripts/*.sh' -exec chmod +x {} +

    echo "Agent -> ~/.copilot/agents"
    mkdir -p "$HOME/.copilot/agents"
    copy_safe "$here/user/agents/sre-triage.agent.md" "$HOME/.copilot/agents/sre-triage.agent.md"

    echo "Commands -> ~/.local/bin"
    mkdir -p "$HOME/.local/bin"
    for s in tf-plan-review/scripts/tf-plan-summary gha-failure-triage/scripts/gha-failed-log \
             gha-workflow-author/scripts/pin-actions npm-maintenance/scripts/npm-audit-summary; do
      ln -sf "$HOME/.copilot/skills/$s.sh" "$HOME/.local/bin/$(basename "$s")"
      echo "  linked: $(basename "$s")"
    done
    case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "NOTE: add ~/.local/bin to your PATH";; esac

    echo "Prerequisites:"
    for t in jq gh perl terraform node npm; do
      command -v "$t" >/dev/null && echo "  ok      $t" || echo "  MISSING $t"
    done
    echo "Next: merge vscode/settings.jsonc into your VS Code user settings, then reload VS Code."
    ;;

  repo)
    target="${2:?usage: ./install.sh repo <path-to-repo>}"
    [[ -d "$target" ]] || { echo "No such directory: $target" >&2; exit 1; }
    mkdir -p "$target/.github/instructions"
    echo "Instructions -> $target/.github"
    copy_safe "$here/repo/.github/copilot-instructions.md" "$target/.github/copilot-instructions.md"
    for f in "$here"/repo/.github/instructions/*.instructions.md; do
      copy_safe "$f" "$target/.github/instructions/$(basename "$f")"
    done
    echo "Tip: trim instructions that don't apply to this repo (e.g. drop terraform.instructions.md in a pure app repo)."
    ;;

  *)
    sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
