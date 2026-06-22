---
description: Plan and implement DevOps work: GitLab CI pipelines, Kubernetes manifests, Helm charts, Terraform infrastructure, and Docker. Auto-loads the relevant skill based on task type.
argument-hint: <ci|k8s|helm|terraform|docker + description>
allowed-tools: Read, Edit, Write, Grep, Glob, Bash
---

# DevOps

Use this command for any infrastructure, pipeline, or deployment work. It detects the task type and loads the right skill automatically.

## Workflow

### Step 1 — Identify the task type

| Task | Skill to load |
|---|---|
| GitLab CI pipeline (`.gitlab-ci.yml`) | `gitlab-ci` |
| Kubernetes manifests (`Deployment`, `Service`, etc.) | `kubernetes` |
| Helm chart | `helm` + `kubernetes` |
| Terraform | `terraform` |
| Dockerfile or Docker Compose | `docker` |
| Full deploy pipeline (CI + K8s + Helm) | `gitlab-ci` + `kubernetes` + `helm` |

### Step 2 — Read context

1. Read the local `CLAUDE.md` to understand the service stack, deployment targets, and team constraints.
2. Inspect existing config: current `.gitlab-ci.yml`, `k8s/`, `helm/`, or `terraform/` directories.
3. Identify what currently works and what is broken or missing.

### Step 3 — Assess current state

Check for common gaps before proposing changes:

**Pipeline:**
- Are secrets hardcoded or in masked CI variables?
- Is there caching for Maven/Gradle and Docker layers?
- Are environments protected with manual approval for production?

**Kubernetes:**
- Are resource limits set?
- Are readiness and liveness probes configured?
- Is the app running as root?

**Helm:**
- Does `values.yaml` have sensible defaults for all environments?
- Are secrets handled externally (not committed)?
- Does the chart pass `helm lint`?

**Terraform:**
- Is state in a remote backend with locking?
- Are provider versions pinned?
- Is there a `plan` step before `apply` in CI?

### Step 4 — Plan changes

Present a plan before making changes. Flag:
- Breaking changes to existing deployments
- Secret or credential handling changes
- Changes that require coordination (DB migrations, rolling restarts, zero-downtime constraints)

### Step 5 — Implement and validate

After approval:
1. Make the changes.
2. Validate:
   - GitLab CI: `gitlab-ci-lint` API or push to a feature branch
   - Kubernetes: `kubectl apply --dry-run=client`
   - Helm: `helm lint` + `helm template --debug`
   - Terraform: `terraform fmt` + `terraform validate` + `terraform plan`
3. Report validation results.

## Output Format

```text
# DevOps Plan: <task>

## Task Type
<pipeline | kubernetes | helm | terraform | docker>

## Current State
<what exists, what is missing or broken>

## Proposed Changes
1. ...

## Risks
- <risk>: <mitigation>

## Validation
- <command and expected result>
```
