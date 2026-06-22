# Kubernetes Manifests Reference

## Deployment for Spring Boot Service

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: payments
  labels:
    app: payment-service
    version: "1.2.0"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: payment-service
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0       # zero-downtime rollout
      maxSurge: 1
  template:
    metadata:
      labels:
        app: payment-service
        version: "1.2.0"
    spec:
      serviceAccountName: payment-service-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
        - name: payment-service
          image: registry.example.com/payment-service:1.2.0
          ports:
            - containerPort: 8080
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: "prod"
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: payment-service-secrets
                  key: db-password
          resources:
            requests:
              cpu: "250m"
              memory: "512Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 10
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 30
            failureThreshold: 3
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh", "-c", "sleep 5"]  # drain connections before shutdown
```

---

## Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  namespace: payments
spec:
  selector:
    app: payment-service
  ports:
    - port: 80
      targetPort: 8080
  type: ClusterIP   # internal only; use Ingress for external access
```

---

## ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: payment-service-config
  namespace: payments
data:
  application.yaml: |
    server:
      port: 8080
    management:
      endpoints:
        web:
          exposure:
            include: health,prometheus
```

Mount as volume:
```yaml
volumes:
  - name: config
    configMap:
      name: payment-service-config
volumeMounts:
  - name: config
    mountPath: /app/config
    readOnly: true
```

---

## Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: payment-service-secrets
  namespace: payments
type: Opaque
stringData:                 # base64-encoded automatically
  db-password: "changeme"
  api-key: "changeme"
```

**In production:** use an external secrets operator (External Secrets Operator + Vault/AWS SSM) instead of managing secrets in manifests.

---

## HorizontalPodAutoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: payment-service
  namespace: payments
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: payment-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

---

## PodDisruptionBudget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: payment-service-pdb
  namespace: payments
spec:
  minAvailable: 1    # or maxUnavailable: 1
  selector:
    matchLabels:
      app: payment-service
```

---

## Resource Sizing Guidelines for JVM Services

| Service size | CPU request | CPU limit | Memory request | Memory limit |
|---|---|---|---|---|
| Small (low traffic) | 100m | 500m | 256Mi | 512Mi |
| Medium | 250m | 1000m | 512Mi | 1Gi |
| Large (high traffic) | 500m | 2000m | 1Gi | 2Gi |

Set `-XX:MaxRAMPercentage=75` in JVM options so the JVM respects container memory limits.

---

## Common Issues

| Symptom | Cause | Fix |
|---|---|---|
| `OOMKilled` | JVM exceeds memory limit | Increase limit or set `MaxRAMPercentage` |
| `CrashLoopBackOff` | App fails to start | Check logs: `kubectl logs <pod> --previous` |
| Pod never becomes Ready | Readiness probe fails | Verify probe path and `initialDelaySeconds` |
| Rolling update stalls | `maxUnavailable: 0` + only 1 replica | Set `replicas >= 2` or allow `maxUnavailable: 1` |
