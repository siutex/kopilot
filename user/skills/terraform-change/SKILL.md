---
name: terraform-change
description: Write or refactor Terraform safely. Use for new resources or modules, renaming or moving resources between modules, converting count to for_each, adopting existing cloud resources with import blocks, dropping resources from state without destroying them, and provider version upgrades. Use for any Terraform edit bigger than a one-liner, especially refactors that could cause destroy/recreate.
argument-hint: "[what to change, and which root module/env]"
---

# Terraform change workflow

1. **Scope narrowly.** Find the root module and files with one targeted search (e.g. the resource address or module name). Ask which environment/root if ambiguous. Read an existing sibling module to copy its conventions instead of scanning the repo.
2. **Edit** following the Terraform instructions file.
3. **Keep state intact.** Every refactor must plan as "0 to destroy":

| Situation | Use |
|---|---|
| Rename, or move into/out of a module | `moved { from = aws_x.old  to = module.m.aws_x.new }` |
| `count` → `for_each` | one `moved` block per index: `from = aws_x.this[0]  to = aws_x.this["api"]` |
| Adopt an existing cloud resource | `import { to = aws_x.this  id = "<cloud id>" }`, then the user runs `terraform plan -generate-config-out=generated.tf` to draft config |
| Stop managing but keep the resource | `removed { from = aws_x.this  lifecycle { destroy = false } }` (TF >= 1.7) |
| Provider major upgrade | separate PR; read the upgrade guide; expect and explain mass in-place updates |

   Suggest `terraform state mv/rm` only if the user explicitly asks.
4. **Validate** (these are safe to run): `terraform fmt -recursive`, then `terraform validate` (run `terraform init -backend=false` first if `.terraform/` is missing). Run `tflint` if `.tflint.hcl` exists.
5. **Hand back** in this order: the diff; the exact plan command for the user (`terraform plan -out=plan.out`); the expected plan result (e.g. "0 to add, 0 to change, 0 to destroy, 4 moved"); a reminder to run `/tf-plan-review plan.out` on the result.
