---
name: tf-plan-review
description: Review a Terraform plan for risk before it is applied. Use whenever the user asks what a plan will do, whether a plan or infra PR is safe to apply, why a resource is being replaced or destroyed, or points to plan output (binary plan file, plan JSON, or a plan log copied from CI). Summarizes with a local script first so the raw plan never enters the chat.
argument-hint: "[plan.out | plan.json | plan.log]"
---

# Terraform plan review

## 1. Summarize first, never read the raw plan
Run the bundled script from the Terraform root module directory:

    tf-plan-summary <plan.out | plan.json | plan.log>

If it is not on PATH, run `bash <this skill's folder>/scripts/tf-plan-summary.sh` ([script](./scripts/tf-plan-summary.sh)).
It accepts a binary plan, `terraform show -json` output, or a text log from CI, and prints attribute names only (no values, so no secrets).
Work only from its output. If there is no plan yet, give the user `terraform plan -out=plan.out` to run themselves; do not run plan yourself, it needs their credentials and backend.

Markers: `!!` = delete/replace of a stateful resource, ` !` = IAM or network access change.

## 2. Assess risk
High risk, always explain:
- `!!` rows: data loss or downtime. Check for deletion protection, backups, and whether the replace is avoidable.
- REPLACE caused by a force-new attribute (`replace:` paths). Often avoidable: revert the rename, or use a `moved` block.
- A run of DELETE + create on `resource[N]` addresses: `count` index shift. Fix with `moved` blocks or `for_each`.
- ` !` rows: widened IAM permissions, new principals, ingress from 0.0.0.0/0 or ::/0. Ask to see only that resource's diff if needed.
- Drift lines: something changed outside Terraform. Applying will revert it; confirm that's intended.

Medium: changes to encryption, DNS, load balancer listeners, autoscaling limits, outputs consumed by other stacks.
Low: tag-only updates, new standalone resources, provider-upgrade noise.

## 3. Answer format (keep under ~25 lines)
Line 1: `Verdict: SAFE | SAFE WITH NOTES | BLOCK`
Then a table with only medium/high rows: `| Risk | Resource | Action | Why | Mitigation |`
Then one line for the rest, e.g. "Also: 12 tag-only updates, 3 new log groups."
If mitigation needs code (e.g. a `moved` block), show the minimal HCL diff.
