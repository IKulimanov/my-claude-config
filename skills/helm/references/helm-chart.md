# Helm Chart Reference

## Chart.yaml

```yaml
apiVersion: v2
name: payment-service
description: Payment processing microservice
type: application
version: 0.1.0        # chart version (semver)
appVersion: "1.2.0"   # application version (informational)

dependencies:
  - name: postgresql
    version: "13.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled   # allow disabling in prod if external DB
```

---

## values.yaml (Annotated)

```yaml
# Application image
image:
  repository: registry.example.com/payment-service
  tag: ""                    # overridden in CI with commit SHA
  pullPolicy: IfNotPresent

# Replica count and autoscaling
replicaCount: 2
autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

# Service
service:
  type: ClusterIP
  port: 80
  targetPort: 8080

# Ingress
ingress:
  enabled: false
  className: nginx
  host: payment.example.com
  tls: true

# Resources
resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi

# Spring-specific
spring:
  profile: prod
  config: {}         # merged into ConfigMap as application.yaml

# External secrets
secrets:
  dbPasswordSecretName: ""    # name of existing K8s Secret

# Health probes
probes:
  readiness:
    path: /actuator/health/readiness
    initialDelaySeconds: 15
  liveness:
    path: /actuator/health/liveness
    initialDelaySeconds: 30

# PodDisruptionBudget
pdb:
  enabled: true
  minAvailable: 1

# ServiceAccount
serviceAccount:
  create: true
  name: ""
```

---

## _helpers.tpl

```go
{{/*
Expand the name of the chart.
*/}}
{{- define "payment-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "payment-service.labels" -}}
helm.sh/chart: {{ include "payment-service.chart" . }}
{{ include "payment-service.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "payment-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "payment-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

---

## Environment Overrides

`values-staging.yaml`:
```yaml
replicaCount: 1

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

ingress:
  enabled: true
  host: payment-staging.example.com
  tls: false

spring:
  profile: staging
```

Deploy:
```bash
helm upgrade --install payment-service ./payment-service \
  -f values-staging.yaml \
  --set image.tag="$IMAGE_TAG" \
  --namespace payments \
  --atomic
```

---

## Helm Hooks for DB Migrations

```yaml
# templates/migration-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "payment-service.name" . }}-migration
  annotations:
    "helm.sh/hook": pre-upgrade,pre-install
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: migrate
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          command: ["java", "-jar", "app.jar", "--spring.batch.job.enabled=false", "db-migrate"]
```

---

## Validation Commands

```bash
# Lint chart
helm lint ./payment-service

# Render templates locally (no cluster)
helm template payment-service ./payment-service -f values-staging.yaml

# Dry-run against cluster
helm upgrade --install payment-service ./payment-service \
  -f values-staging.yaml \
  --dry-run --debug

# Diff before apply (requires helm-diff plugin)
helm diff upgrade payment-service ./payment-service -f values-prod.yaml
```
