---
name: helm
description: Use when creating or modifying Helm charts for Java/Spring services. Covers chart structure, values files, template helpers, multi-environment values, hooks, and release management.
---

# Helm

Use this skill when creating, updating, or troubleshooting Helm charts for service deployments.

## When To Use

- Creating a new Helm chart for a Spring Boot service
- Structuring values files for multiple environments
- Writing or debugging Go templates in `templates/`
- Setting up Helm hooks (pre-install, pre-upgrade migration jobs)
- Managing chart dependencies
- Validating a chart before deployment (`helm lint`, `helm template`)

## Workflow

1. Read the local `CLAUDE.md` for the service stack and deployment constraints.
2. Load `references/helm-chart.md` for chart structure patterns.
3. For the underlying K8s manifests, also load the `kubernetes` skill.
4. Validate: `helm lint`, `helm template --debug`, `helm upgrade --dry-run` before applying.

## Standard Chart Layout

```
my-service/
  Chart.yaml          # metadata
  values.yaml         # defaults
  values-staging.yaml # environment overrides
  values-prod.yaml    # environment overrides
  templates/
    _helpers.tpl      # named templates and labels
    deployment.yaml
    service.yaml
    configmap.yaml
    ingress.yaml
    hpa.yaml
    pdb.yaml
    serviceaccount.yaml
    NOTES.txt
```

## Guardrails

- Keep `values.yaml` as the source of defaults — all values should have a default.
- Do not hardcode environment-specific values in templates — use `values-{env}.yaml` overrides.
- Never put secrets in `values.yaml` or commit them to git — use Helm Secrets plugin or external secrets.
- Use `_helpers.tpl` for reusable label blocks to ensure consistency across templates.
- Always `helm lint` before committing a chart change.
- Use `helm upgrade --atomic` in CI to auto-rollback on failed deployments.
- Pin chart dependencies to exact versions in `Chart.lock`.
- Use `helm diff` (plugin) to review changes before applying in production.
