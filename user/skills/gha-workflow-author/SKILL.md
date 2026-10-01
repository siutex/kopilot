---
name: gha-workflow-author
description: Create, review, or harden GitHub Actions workflows and composite/reusable actions, including Terraform plan/apply pipelines, Node/npm CI, deploy jobs, OIDC cloud auth, permissions, caching, concurrency, and pinning actions to commit SHAs. Use whenever the user writes, edits, reviews, or asks about anything under .github/workflows or an action.yml, even for small changes.
argument-hint: "[new <what> | review <file> | pin]"
---

# GitHub Actions authoring

## New workflow: start from a template, never from scratch
- Terraform plan on PR + gated apply on main: [terraform-pipeline.yml](./references/terraform-pipeline.yml)
- Node/npm CI: [node-ci.yml](./references/node-ci.yml)

Read only the template you need. Adapt paths, working directory and the cloud login block.
Templates use `@LATEST`. After writing the file, pin with the bundled [pin-actions](./scripts/pin-actions.sh) script: `pin-actions <file>` (dry run), then give the user `pin-actions --write <file>`. Never type a commit SHA yourself.

## Review / hardening checklist
Report only failures, one line each: `file:line | problem | fix`.
1. Top-level `permissions: contents: read`; extra scopes only on the jobs that need them.
2. Third-party actions pinned to 40-char SHAs with a tag comment.
3. No untrusted `${{ github.event.* }}` / `github.head_ref` inside `run:`; route through `env:` and quote.
4. No `pull_request_target` combined with checkout of the PR head ref.
5. Secrets: never echoed; no `secrets: inherit` into workflows you don't control; prod secrets scoped to an `environment`.
6. Cloud auth via OIDC, and the trust policy restricts repo + branch/environment.
7. Every job has `timeout-minutes`; deploy/apply jobs have a non-cancelling `concurrency` group.
8. npm: `setup-node` with `cache: npm` and `npm ci` (don't cache node_modules by hand).
9. Triggers: `paths` filters on monorepos; `workflow_dispatch` for manual operations.
10. Terraform: apply uses the plan file from the same run, behind a protected environment.

If `actionlint` is installed, run it on changed files. It catches expression and shell errors for free, before you spend a CI run.
