# Terraform Patterns Reference

## Module Structure

```hcl
# variables.tf
variable "environment" {
  type        = string
  description = "Deployment environment: staging or prod"
  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "environment must be staging or prod"
  }
}

variable "service_name" {
  type    = string
  default = "payment-service"
}

variable "image_tag" {
  type        = string
  description = "Docker image tag to deploy"
}

# outputs.tf
output "service_url" {
  description = "Public URL of the deployed service"
  value       = aws_lb.main.dns_name
}
```

---

## Naming and Tagging

Use `locals` for consistent naming and tagging:

```hcl
locals {
  name_prefix = "${var.environment}-${var.service_name}"

  common_tags = {
    Environment = var.environment
    Service     = var.service_name
    ManagedBy   = "terraform"
    Owner       = "payments-team"
  }
}

resource "aws_instance" "app" {
  # ...
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app"
  })
}
```

---

## Remote Backend with State Locking

```hcl
# backend.tf (S3 example)
terraform {
  backend "s3" {
    bucket         = "my-org-terraform-state"
    key            = "payment-service/staging/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

---

## Provider and Module Versioning

```hcl
terraform {
  required_version = "~> 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}
```

---

## For_each vs Count

Prefer `for_each` over `count` for resources that have a meaningful identity:

```hcl
# Good: resources identified by name, not index
resource "aws_iam_user" "app_users" {
  for_each = toset(var.app_user_names)
  name     = each.value
}

# Bad: index-based (reordering causes replacement)
resource "aws_iam_user" "app_users" {
  count = length(var.app_user_names)
  name  = var.app_user_names[count.index]
}
```

---

## Sensitive Values

```hcl
variable "db_password" {
  type      = string
  sensitive = true    # redacted in plan/apply output
}

output "db_connection_string" {
  value     = "postgresql://user:${var.db_password}@${aws_db_instance.main.endpoint}/db"
  sensitive = true
}
```

Never put sensitive values in `terraform.tfvars` and commit to git. Use:
- Environment variables: `TF_VAR_db_password`
- A secrets manager (Vault, AWS SSM) with a data source

---

## GitLab CI Integration

```yaml
# .gitlab-ci.yml excerpt
.terraform-base:
  image: hashicorp/terraform:1.6
  before_script:
    - terraform init -input=false

terraform-plan:
  extends: .terraform-base
  stage: test
  script:
    - terraform plan -input=false -out=tfplan
  artifacts:
    paths: [tfplan]
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

terraform-apply:
  extends: .terraform-base
  stage: deploy
  script:
    - terraform apply -input=false tfplan
  when: manual
  rules:
    - if: $CI_COMMIT_BRANCH == "master"
  needs: [terraform-plan]
```

---

## Common Pitfalls

| Problem | Cause | Fix |
|---|---|---|
| State drift | Manual changes in console | Import resources or use `terraform refresh` |
| Accidental destroy | `count` list reorder | Switch to `for_each` |
| Locked state | Previous run crashed | `terraform force-unlock <lock-id>` (cautiously) |
| Sensitive in output | Not marking as `sensitive` | Add `sensitive = true` |
| Provider version conflict | No version pin | Pin with `~>` |
