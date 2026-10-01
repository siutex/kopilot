---
applyTo: ".github/workflows/**,**/action.yml,**/action.yaml"
description: GitHub Actions conventions
---
- Pin third-party actions to a full commit SHA with the tag as a comment (`@<40-char-sha> # v4.2.2`). Resolve SHAs with the `pin-actions` script; never write a SHA from memory.
- Top-level `permissions: contents: read`. Grant more per job only when needed (`id-token: write` for OIDC, `pull-requests: write` for PR comments).
- Cloud auth through OIDC. No long-lived cloud keys in secrets.
- Never interpolate untrusted input (`github.event.*` titles/bodies/branch names, `github.head_ref`) directly in `run:`. Pass it through `env:` and quote it.
- Don't use `pull_request_target` together with a checkout of the PR head.
- Every job has `timeout-minutes`. Deploy/apply jobs have a `concurrency` group with `cancel-in-progress: false`.
- Terraform: plan on PR; apply only on the default branch, through a protected `environment`, using the plan file produced in the same run.
- Node: `actions/setup-node` with `node-version-file: .nvmrc` and `cache: npm`; install with `npm ci`, never `npm install`.
- Share logic through reusable workflows (`workflow_call`) or composite actions instead of copy-paste.
