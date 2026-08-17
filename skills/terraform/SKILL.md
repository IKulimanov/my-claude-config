---
name: terraform
description: Use when writing or reviewing Terraform infrastructure code. Covers module structure, state management, variable and output patterns, resource naming, workspace usage, and best practices for provisioning cloud infrastructure. Triggers on .tf/.tfvars files, `terraform plan/apply`, modules, providers, remote state.
paths: "**/*.tf,**/*.tfvars,**/*.tf.json"
---

# Terraform

Use this skill when creating or modifying Terraform infrastructure code for cloud provisioning.

## When To Use

- Writing new Terraform modules or resources
- Structuring a Terraform project (module layout, state backends)
- Reviewing Terraform code for correctness and safety
- Managing state: backends, workspaces, remote state references
- Setting up CI/CD with Terraform (plan on MR, apply on merge)
- Debugging `terraform plan` output or state drift

## Workflow

1. Read the local `CLAUDE.md` for the infrastructure context and cloud provider.
2. Load `references/terraform-patterns.md` for module structure and resource patterns.
3. Always run `terraform plan` and review output before proposing `apply`.
4. For GitLab CI integration, load the `gitlab-ci` skill.

## Project Structure

```
infra/
  modules/
    payment-service/      # reusable module
      main.tf
      variables.tf
      outputs.tf
      README.md
  environments/
    staging/
      main.tf             # calls module with staging vars
      terraform.tfvars
      backend.tf
    prod/
      main.tf
      terraform.tfvars
      backend.tf
```

## Guardrails

- Never commit `terraform.tfstate` or `.tfvars` files with secrets to git.
- Always use a remote backend (S3 + DynamoDB, GCS, GitLab-managed) with state locking.
- Pin provider and module versions — use `~>` for minor version flexibility, never leave version unconstrained.
- Run `terraform plan` in CI on every MR; run `terraform apply` only on merge to main.
- Use `terraform fmt` and `terraform validate` in CI before plan.
- Destroy operations require explicit human approval — never auto-apply destroy.
- Separate modules for different lifecycles (networking vs. application vs. data stores).
- Use `locals` to avoid repeating tag/naming logic across resources.
- Output only what downstream modules or docs need — do not expose internal details.
