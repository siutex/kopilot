# Copilot SRE Kit

GitHub Copilot setup for an SRE working with **Terraform + GitHub Actions + npm-based apps**, designed around a **small monthly AI budget**.

## The idea: spend tokens on thinking, not on reading

Most of an SRE's AI spend goes on feeding the model huge inputs: CI logs, Terraform plans, `npm audit` JSON, lockfiles. This kit moves that work to local scripts and keeps Copilot's context small.

| Layer | What it does | Cost |
|---|---|---|
| **Summary scripts** | `gha-failed-log`, `tf-plan-summary`, `npm-audit-summary` shrink inputs 20-50x (tested: a 650-line CI log became 34 lines; a 29 KB `npm audit` became ~1.5 KB). Often the output alone answers your question. | Free |
| **Instructions** | One ~20-line always-on file, plus Terraform / Actions / npm rules that load only when matching files are involved. | Tiny, every request |
| **Skills** | Six workflows. Only name + description sit in context; the body loads when the task matches or you type `/skill-name`. | Only when used |
| **SRE Triage agent** | Read-only, 3 tool sets, answers in 15 lines max, hands off to the normal agent for edits. | Low per request |

## What's inside

```
copilot-sre-kit/
├── install.sh
├── vscode/settings.jsonc                  merge into VS Code user settings
├── repo/.github/                          -> into each repository
│   ├── copilot-instructions.md            always on (kept tiny)
│   └── instructions/
│       ├── terraform.instructions.md      *.tf, *.tfvars, *.hcl
│       ├── github-actions.instructions.md .github/workflows/**, action.yml
│       └── node-npm.instructions.md       package.json, .npmrc, .nvmrc, Dockerfile
└── user/                                  -> ~/.copilot (every workspace)
    ├── agents/sre-triage.agent.md
    └── skills/
        ├── tf-plan-review/        + scripts/tf-plan-summary.sh
        ├── terraform-change/      moved/import/removed refactors, validation
        ├── gha-failure-triage/    + scripts/gha-failed-log.sh
        ├── gha-workflow-author/   + scripts/pin-actions.sh, references/*.yml templates
        ├── npm-maintenance/       + scripts/npm-audit-summary.sh
        └── incident-comms/        + assets/postmortem-template.md (manual /incident-comms only)
```

Skills and the agent live at user level because you work across many repos (infra repos plus the app repos you support). Instructions live in each repo, so teammates benefit too.

## Install (about 5 minutes)

1. **Prerequisites:** `jq`, `perl`, `gh` (then `gh auth login`), `terraform`, `node`/`npm`. Optional but recommended: `tflint`, `actionlint`.
2. **User-level pieces:** `./install.sh user`. This copies skills and the agent into `~/.copilot/` and puts the four scripts on your PATH (`~/.local/bin`).
3. **Settings:** merge `vscode/settings.jsonc` into your VS Code *user* settings JSON. It limits inline completions to useful file types, keeps `.terraform/`, `node_modules/`, lockfiles and state out of agent search, caps agent loops, and sets terminal approval rules (auto-approve read-only commands, always ask for `terraform apply`, `git push`, `npm audit fix` and similar).
4. **Per repo:** `./install.sh repo ~/src/<repo>`, remove instruction files that don't apply (e.g. Terraform rules in a pure app repo), and commit `.github/`.
5. **Verify:** reload VS Code. In the Chat view, right-click and choose **Diagnostics** to see loaded instructions, skills and agents. Type `/` in chat to see the skills as commands, and check that **SRE Triage** is in the agent dropdown.

## Daily playbook

Always try the left column first. Escalate to Copilot only when the summary doesn't already tell you the answer.

| Situation | Free first step (terminal) | If you need Copilot |
|---|---|---|
| PR check / pipeline is red | `gha-failed-log` or `gha-failed-log <run-url>` | SRE Triage: `/gha-failure-triage <run-url>` |
| Is this plan safe to apply? | `terraform plan -out=plan.out && tf-plan-summary plan.out` | SRE Triage: `/tf-plan-review plan.out` |
| Plan only exists in CI | save the job's plan output as `plan.log`, then `tf-plan-summary plan.log` | same as above, with `plan.log` |
| Write new Terraform | inline completions (Tab) | inline chat (Ctrl/Cmd+I) on the selection |
| Rename / move / count→for_each / import | none | Agent: `/terraform-change <what>`, then `/tf-plan-review` |
| New or changed workflow | `actionlint`, `pin-actions` | Agent: `/gha-workflow-author new terraform pipeline for infra/prod` |
| Review a workflow's security | none | SRE Triage: `/gha-workflow-author review .github/workflows/x.yml` |
| Dependabot / `npm audit` alert | `npm-audit-summary` | SRE Triage: `/npm-maintenance <pkg or GHSA id>` |
| `npm ci` / ERESOLVE failure | `npm explain <pkg>` | `/npm-maintenance` with the error line |
| Node version upgrade | none | Agent: `/npm-maintenance node upgrade to <version>` |
| Incident | none | `/incident-comms update` + pasted notes; later `/incident-comms postmortem` |

## Budget rules

1. **Scripts first.** Half the time the summary is the answer, and it costs nothing.
2. **Cheapest surface that works:** inline completion < inline chat on a selection < SRE Triage agent < full Agent. Use the full Agent only for multi-file edits.
3. **One chat per task.** Start a new session (Ctrl/Cmd+N) when switching topics; long threads re-send their history on every turn. Use `/compact` if a thread must continue.
4. **Attach exactly what's needed.** `#file` or a selection, not `#codebase`. Paste script output, never raw logs.
5. **Model choice.** Auto model selection is a good default. Optionally pin a Low cost-tier model in `sre-triage.agent.md` (hover over models in the picker to see the tier), and switch to a stronger model only for gnarly refactors.
6. **Leave thinking effort at default.** Raise it only for genuinely hard debugging or design.
7. **Invoke skills explicitly** with `/name` when you know which one you need; it avoids the agent guessing and exploring.
8. **Watch the meter.** Hover over a chat response to see its credit cost; the context-window control in the chat input shows the session total; the Copilot icon in the Status Bar shows the month's usage. Check after your first two or three days and extrapolate to the month.

### About your "20k" limit
Copilot now meters chat and agent usage as **AI credits** that depend on the model and the tokens processed. Open the Copilot status dashboard (Status Bar) to see exactly what your 20k measures. If it really is 20,000 *tokens*, that's only a handful of agent-mode requests, since each one carries system prompt, tool definitions, instructions and files. In that case lean almost entirely on scripts plus inline completions, and treat chat as a last resort. The VS Code docs list inline suggestions as metered only on the Copilot Free plan, so on a business plan they most likely don't draw from this allowance; confirm with your Copilot admin.

## Customizing

- **Add your specifics** (cloud provider, naming scheme, module registry, environments) to `copilot-instructions.md`, but keep it short since it's sent with every request. Put anything long into a skill instead.
- **Capture a workflow as a new skill:** after solving something tricky, type `/create-skill` or ask "create a skill from how we just debugged that". Keep the result lean, and move bulky reference material into files next to `SKILL.md`, which load only when referenced.
- **Share skills with the team:** copy folders from `user/skills/` into a repo's `.github/skills/`.
- **Heavy investigations:** adding `context: fork` to a skill's frontmatter (experimental) runs it in a subagent so only the result returns to your main chat. It keeps the main thread short but doesn't make the work itself cheaper.

## Safety notes

- The terminal approval rules are a convenience, not a security boundary. Locally, use read-only cloud credentials (a plan role) so that even a mistaken command can't change infrastructure.
- Plan files and plan artifacts can contain sensitive values. `tf-plan-summary` prints attribute names only, never values, and the pipeline template keeps plan artifacts for 3 days.
- `pin-actions` is dry-run by default. Review `git diff` after `--write`.

## Troubleshooting

| Problem | Fix |
|---|---|
| Skill not listed | Folder name must equal `name:` (lowercase, hyphens); check Chat → right-click → Diagnostics. |
| Skill doesn't trigger automatically | Invoke it with `/skill-name`. `incident-comms` is manual-only by design. |
| Agent missing from dropdown | Check `~/.copilot/agents/sre-triage.agent.md` exists, then reload the window. |
| "Unknown configuration setting" | VS Code renamed it; search for the feature in the Settings UI. |
| `gha-failed-log` auth errors | `gh auth status`; for SSO orgs, authorize the token for the org. |
| `tf-plan-summary plan.out` fails | Run it in the same initialised root module that produced the plan, or convert with `terraform show -json plan.out > plan.json` there first. |
| `pin-actions` WARN lines | Typo in the ref, private action repo without access, or GitHub API rate limit (`gh auth login` raises it). |
