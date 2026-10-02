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
| `spec.scope.workloadTypes` | `[Deployment, StatefulSet, CronJob, Rollout, Job, AnalysisRun, DaemonSet, Model]` | Workload kinds this policy applies to. Default excludes `StrimziPodSet` only. |
| `spec.scope.containers` | all automatable containers | Exact container names to retain from external recommendations. Unknown names are allowed. |
| `spec.automationStrategyRef.name` | none | Required namespaced strategy name. |
| `spec.weight` | `0` | Higher weight takes precedence when same-kind policies compete. |
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
    containers:
      - api
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
- Container filtering happens before recommendation age and `KubexAutomation` checks, so summaries cover only containers owned by the policy.
- By default, only one same-kind proactive policy contributes to a workload. With `globalConfiguration.multiPolicyContainerRightsizingEnabled: true`, policies can contribute to separate container/resource targets; `PolicyEvaluation` resolves overlapping targets. See [Multi-Policy Container Rightsizing](./Multi-Policy-Container-Rightsizing.md).
- `Model` is included in default workload types. Use `spec.scope.workloadTypes: [Model]` when you want to restrict scope to KubeAI `Model` objects only. Recommendations and rollback state are stored on the `Model` owner, then inherited by model-owned pods.
- For cluster-scoped examples and field references, see [Cluster Proactive Policies](./Cluster-Proactive-Policies.md).
- EXPERIMENTAL: Recommendations can now include `gpu.gpuOverallOptimal`, which is applied as a proactive `requests.gpu` target. See the [GPU Sharing with KAI](./GPU-Sharing-with-KAI.md) guide for more information.
