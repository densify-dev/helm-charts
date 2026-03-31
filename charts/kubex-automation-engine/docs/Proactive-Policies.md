# Proactive Policies

`ProactivePolicy` applies Kubex recommendations to matching workloads within a namespace.

Use it when you want resource targets to come from Kubex recommendation data instead of fixed values in the manifest, and the policy should be owned within a single namespace.

For the cluster-scoped variant, see [Cluster Proactive Policies](./Cluster-Proactive-Policies.md).

## Scope Mapping

- `ProactivePolicy` is namespaced and references an `AutomationStrategy` in the same namespace.
- `ClusterProactivePolicy` is cluster-scoped and references a `ClusterAutomationStrategy`; that resource is documented separately in [Cluster Proactive Policies](./Cluster-Proactive-Policies.md).

## Field Reference

## `ProactivePolicy.spec`

| Field | Default | Description |
| --- | --- | --- |
| `spec.scope` | none | Optional scope object for workload selection. |
| `spec.scope.labelSelector` | none | Kubernetes label selector for matching workloads. |
| `spec.scope.workloadTypes` | `[Deployment, StatefulSet, CronJob, Rollout, Job, AnalysisRun, DaemonSet]` | Workload kinds this policy applies to. |
| `spec.scope.containerSelector.field` | none | Container field to match. Only `Name` is supported. |
| `spec.scope.containerSelector.patterns` | none | Shell-style `*` glob patterns for in-scope container names. |
| `spec.automationStrategyRef.name` | none | Required namespaced strategy name. |
| `spec.weight` | `0` | Higher weight wins when multiple proactive policies match. |
| `spec.safetyChecks.maxAnalysisAgeDays` | `5` | Rejects old recommendations. |

## Example: Namespaced Proactive Policy

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ProactivePolicy
metadata:
  name: team-a-proactive
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
  automationStrategyRef:
    name: team-a-balanced
  weight: 100
  safetyChecks:
    maxAnalysisAgeDays: 3
```

## Notes

- Use namespaced proactive policies when teams own their own namespaces.
- `scope.containerSelector` filters Kubex recommendations to matching containers after the workload itself is selected.
- When multiple proactive policies of the same kind match, higher `weight` wins, then older objects win on ties.
- For cluster-scoped examples and field references, see [Cluster Proactive Policies](./Cluster-Proactive-Policies.md).
