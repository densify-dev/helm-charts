# Cluster Proactive Policies

`ClusterProactivePolicy` applies Kubex recommendations to matching workloads across one or more namespaces.

Use it when a platform team wants recommendation-driven automation with shared scope rules and a reusable `ClusterAutomationStrategy`.

For the namespaced variant, see [Proactive Policies](./Proactive-Policies.md). For the referenced strategy resource, see [Cluster Automation Strategies](./Cluster-Automation-Strategies.md).

## Reference Rules

- `ClusterProactivePolicy` is cluster-scoped and references a `ClusterAutomationStrategy`.
- Helm can generate `ClusterProactivePolicy` resources from `scope`, but they can also be managed directly with manifests or GitOps.
- If multiple cluster proactive policies match the same workload, higher `spec.weight` wins, then older objects win on ties.

## Field Reference

| Field | Default | Description |
| --- | --- | --- |
| `spec.scope.labelSelector` | none | Kubernetes label selector for matching workloads. |
| `spec.scope.workloadTypes` | `[Deployment, StatefulSet, CronJob, Rollout, Job, AnalysisRun, DaemonSet]` | Workload kinds this policy applies to. |
| `spec.scope.containerSelector.field` | none | Container field to match. Only `Name` is supported. |
| `spec.scope.containerSelector.patterns` | none | Shell-style `*` glob patterns for in-scope container names. |
| `spec.scope.namespaceSelector.operator` | none | Namespace selector operator: `In` or `NotIn`. |
| `spec.scope.namespaceSelector.values` | none | Namespace patterns to include or exclude. |
| `spec.automationStrategyRef.name` | none | Required cluster strategy name. |
| `spec.weight` | `0` | Higher weight wins when multiple proactive policies match. |
| `spec.safetyChecks.maxAnalysisAgeDays` | `5` | Rejects old recommendations. |

## Example

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterProactivePolicy
metadata:
  name: platform-prod-proactive
spec:
  scope:
    containerSelector:
      field: Name
      patterns:
        - api*
        - worker
    labelSelector:
      matchLabels:
        team: platform
      matchExpressions:
        - key: environment
          operator: In
          values:
            - production
            - staging
    workloadTypes:
      - Deployment
      - StatefulSet
      - Rollout
    namespaceSelector:
      operator: NotIn
      values:
        - kube-system
        - kubex
  automationStrategyRef:
    name: platform-conservative
  weight: 50
  safetyChecks:
    maxAnalysisAgeDays: 5
```

## Notes

- Use cluster proactive policies when a platform team needs one recommendation-driven policy across many namespaces.
- `scope.containerSelector` filters Kubex recommendations after workload and namespace scope are resolved.
- Start with narrow namespace and label selectors, then widen scope after verifying the selected-policy behavior in events and controller logs.
- If you need per-namespace ownership instead, use namespaced `ProactivePolicy`.
