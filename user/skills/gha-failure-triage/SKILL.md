---
name: gha-failure-triage
description: Diagnose a failed GitHub Actions run and propose the smallest fix. Use whenever a workflow, CI check, deploy pipeline, Terraform job or npm build failed, a PR check is red, or the user pastes a run URL or run ID. Fetches a trimmed failure excerpt with the gh CLI so full logs never enter the chat.
argument-hint: "[run URL | run ID | empty = latest failed run on current branch]"
---

# GitHub Actions failure triage

## 1. Get the excerpt
Run `gha-failed-log [run-id|run-url]` (or `bash <this skill's folder>/scripts/gha-failed-log.sh`, see [script](./scripts/gha-failed-log.sh)).
No argument = latest failed run on the current branch. Needs an authenticated `gh`.
Output is capped at ~120 lines. Only if the cause is clearly cut off, rerun once with `MAX_LINES=250`.

## 2. Classify (pick one)
| Class | Typical signals | Usual fix |
|---|---|---|
| Code / test | assertion, compile/TS/lint error | fix code, not CI |
| Dependency | `npm ERR!`, ERESOLVE, 404/E401 from registry, "lock file out of sync" | see npm-maintenance skill |
| Terraform | `Error:` from init/plan/apply, state lock, provider schema | see terraform-change skill; state lock: give user `terraform force-unlock <id>` only after confirming no run is active |
| Auth / permissions | 403, "Resource not accessible by integration", `AssumeRoleWithWebIdentity`, `AADSTS`, workload identity errors | job `permissions:` (e.g. `id-token: write`), OIDC trust policy subject (repo, branch, environment) |
| Runner / resources | job-level failure with no failed step, exit 137, "no space left", timeout | `timeout-minutes`, `NODE_OPTIONS=--max-old-space-size`, cleanup, bigger runner |
| Flaky / external | ECONNRESET, 5xx, rate limit, passes on retry | rerun; add retry only at the network call |
| Workflow config | YAML/expression error, unknown input, empty secret or var | fix workflow; check secret/var exists for that environment |

## 3. Confirm cheaply
Read at most the one or two files the error points to (the workflow file, the failing script or test). Don't open unrelated files.

## 4. Answer (under ~15 lines)
- `Cause:` one sentence, quoting the single most telling log line.
- `Fix:` minimal diff or command.
- `Verify:` how to confirm (local command or which job to watch).
If flaky, say so and give `gh run rerun <id> --failed` for the user to run (don't run it yourself).
