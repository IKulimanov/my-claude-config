---
name: kubernetes
description: Use when writing or reviewing Kubernetes manifests for Java/Spring services. Covers Deployment, Service, ConfigMap, Secret, Ingress, resource limits, health probes, HPA, RBAC basics, and rollout strategy.
---

# Kubernetes

Use this skill when writing, reviewing, or troubleshooting Kubernetes manifests for service deployments.

## When To Use

- Writing Deployment, Service, ConfigMap, or Ingress manifests
- Configuring resource limits and requests
- Setting up liveness and readiness probes for a Spring Boot service
- Configuring HPA for auto-scaling
- Rolling out a new version (strategy, PodDisruptionBudget)
- Reviewing RBAC for a service account
- Debugging CrashLoopBackOff or OOMKilled pods

## Workflow

1. Read the local `CLAUDE.md` to understand the service stack and infra constraints.
2. Identify the manifest type: new service, update to existing, or infra component.
3. Load `references/k8s-manifests.md` for manifest patterns and guardrails.
4. For Helm-packaged deployments, also load the `helm` skill.
5. Validate: check resource limits, probe paths, secret handling, and rollout strategy.

## Guardrails

- Always set `resources.requests` and `resources.limits` — pods without limits get evicted first.
- Never run pods as root (`runAsNonRoot: true`).
- Never put secret values in ConfigMap — use Secret or an external secrets operator.
- `readinessProbe` determines when traffic is sent; `livenessProbe` determines when to restart. They serve different purposes — always configure both.
- For Spring Boot: use `/actuator/health/readiness` and `/actuator/health/liveness` as probe paths.
- Set `PodDisruptionBudget` for production services to prevent all replicas being evicted simultaneously.
- Use `RollingUpdate` strategy with `maxUnavailable: 0` for zero-downtime deployments.
- Namespace everything — do not deploy to `default` in production.
