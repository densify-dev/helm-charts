# Static Policies

Static policies apply explicit request and limit values to matching workloads.

Use them when you want deterministic resource values instead of recommendation-driven sizing.

## Scope Mapping

- `StaticPolicy` is namespaced and references an `AutomationStrategy` in the same namespace.
- `ClusterStaticPolicy` is cluster-scoped and references a `ClusterAutomationStrategy`.

## Field Reference

## `StaticPolicy.spec`

| Field | Default | Description |
| --- | --- | --- |
| `spec.scope` | none | Optional scope object for workload selection in the same namespace. |
| `spec.scope.labelSelector` | none | Kubernetes label selector for matching workloads. |
| `spec.scope.workloadTypes` | `[Deployment, StatefulSet, CronJob, Rollout, Job, AnalysisRun, DaemonSet]` | Workload kinds this policy applies to. |
| `spec.scope.containerSelector.field` | none | Container field to match. Only `Name` is supported. |
| `spec.scope.containerSelector.patterns` | none | Shell-style `*` glob patterns for in-scope container names. |
| `spec.resources.containers` | none | Map of container names to requests and limits. Use `"*"` for all containers. |
| `spec.weight` | `0` | Higher weight wins when multiple static policies match. |
| `spec.automationStrategyRef.name` | none | Required namespaced strategy name. |

## `ClusterStaticPolicy.spec`

| Field | Default | Description |
| --- | --- | --- |
| `spec.scope.labelSelector` | none | Kubernetes label selector for matching workloads. |
| `spec.scope.workloadTypes` | `[Deployment, StatefulSet, CronJob, Rollout, Job, AnalysisRun, DaemonSet]` | Workload kinds this policy applies to. |
| `spec.scope.containerSelector.field` | none | Container field to match. Only `Name` is supported. |
| `spec.scope.containerSelector.patterns` | none | Shell-style `*` glob patterns for in-scope container names. |
| `spec.scope.namespaceSelector.operator` | none | Namespace selector operator: `In` or `NotIn`. |
| `spec.scope.namespaceSelector.values` | none | Namespace patterns to include or exclude. |
| `spec.resources.containers` | none | Map of container names to requests and limits. Use `"*"` for all containers. |
| `spec.weight` | `0` | Higher weight wins when multiple static policies match. |
| `spec.automationStrategyRef.name` | none | Required cluster strategy name. |

## Example: Namespaced Static Policy

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: StaticPolicy
metadata:
  name: team-a-fixed-resources
  namespace: team-a
spec:
  scope:
    containerSelector:
      field: Name
      patterns:
        - api*
        - worker
    labelSelector:
      matchLabels:
        app.kubernetes.io/part-of: storefront
      matchExpressions:
        - key: tier
          operator: In
          values:
            - api
            - worker
    workloadTypes:
      - Deployment
      - StatefulSet
  resources:
    containers:
      "*":
        requests:
          cpu: "250m"
          memory: "512Mi"
        limits:
          cpu: "1"
          memory: "1Gi"
      api:
        requests:
          cpu: "500m"
          memory: "1Gi"
        limits:
          cpu: "2"
          memory: "2Gi"
  weight: 100
  automationStrategyRef:
    name: team-a-balanced
```

## Example: Cluster Static Policy

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterStaticPolicy
metadata:
  name: platform-database-baseline
spec:
  scope:
    containerSelector:
      field: Name
      patterns:
        - postgres
        - metrics
    labelSelector:
      matchLabels:
        tier: database
    workloadTypes:
      - StatefulSet
    namespaceSelector:
      operator: In
      values:
        - prod-*
        - shared-services
  resources:
    containers:
      postgres:
        requests:
          cpu: "1"
          memory: "2Gi"
        limits:
          cpu: "2"
          memory: "4Gi"
      metrics:
        requests:
          cpu: "200m"
          memory: "256Mi"
        limits:
          cpu: "500m"
          memory: "512Mi"
  weight: 200
  automationStrategyRef:
    name: platform-conservative
```

## Notes

- Use static policies when exact values matter more than recommendation-driven tuning.
- `resources.containers."*"` applies a default to every container, and named containers can override it.
- When `scope.containerSelector` is set, only matching containers receive static resources; wildcard `resources.containers."*"` is expanded only across those matching container names.
- When multiple static policies of the same kind match, higher `weight` wins, then older objects win on ties.
