---
applyTo: "**/*.tf,**/*.tfvars,**/*.hcl"
description: Terraform conventions
---
- Refactor with `moved`, `import` and `removed` blocks (TF >= 1.7 for `removed`), never with `terraform state mv/rm`.
- Pin `required_version` and providers with `~>` in versions.tf. Don't bump a provider major version as a side effect.
- Prefer `for_each` with stable string keys over `count` for anything that can be reordered or removed.
- Every variable has `type` and `description`; add `validation` for constrained values; secrets get `sensitive = true` and no default.
- No hardcoded account/subscription/project IDs, regions, ARNs or resource IDs: use variables, data sources or locals.
- Stateful resources (DBs, buckets, disks, keys, DNS zones) get deletion protection or `lifecycle { prevent_destroy = true }`.
- Apply tags/labels through provider default tags/labels where supported.
- Module layout: main.tf, variables.tf, outputs.tf, versions.tf. Every output has a description.
- After editing, run `terraform fmt -recursive` and `terraform validate` (plus `tflint` if `.tflint.hcl` exists). Never plan against real backends or apply.
