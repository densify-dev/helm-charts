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

## Ephemeral Storage

Kubex can right-size container ephemeral-storage requests and limits, the same way it does for CPU and memory. It is off by default, and turning it on takes two steps. Upgrading the chart doesn't change storage on any workload until both are done.

1. Turn it on for the controller in your Helm values. Do this only if your Kubex instance is on a rapid release that supports ephemeral-storage automation. On any other release, leave it off.

    ```yaml
    controllerManager:
      extraEnv:
        - name: EPHEMERAL_STORAGE_AUTOMATION_ENABLED
          value: "true"
    ```

2. Allow storage changes in each `AutomationStrategy` or `ClusterAutomationStrategy` that should make them. Every storage change is off in a strategy until you set it to `true`:

    ```yaml
    spec:
      enablement:
        ephemeralStorage:
          requests:
            upsize: true
            downsize: true
            setFromUnspecified: true
          limits:
            upsize: true
            downsize: true
            setFromUnspecified: true
    ```

Strategies created from `policy.policies` in your Helm values can't turn on storage changes. Use an `AutomationStrategy` or `ClusterAutomationStrategy` instead.

**What it means for your workloads**

- Kubernetes cannot change ephemeral storage on a running pod. By default, Kubex applies storage changes the next time the pod is recreated (for example a rollout, scale-up, or node drain). A container crash restart does not apply them. They never cause an eviction.
- CPU and memory rightsizing for the same pod is unaffected and happens as usual.
- Set `restartStrategy: Evict` to let Kubex restart the pod to apply storage changes. This requires `podEviction.enabled: true` in the strategy. A pod with CPU or memory changes together with storage changes is then restarted once to apply all of them.

```yaml
spec:
  podEviction:
    enabled: true
  enablement:
    ephemeralStorage:
      restartStrategy: Evict
```

**Limit or turn off storage changes**

Limit storage changes with `floor`, `ceiling`, and per-container overrides under `enablement.ephemeralStorage`. To stop them in one strategy, set its storage fields back to `false` or remove them. To stop them everywhere, remove `EPHEMERAL_STORAGE_AUTOMATION_ENABLED` from your Helm values.

See [Automation Strategies](./Automation-Strategies.md) for the full field list.

**Safety and scope**

- Storage changes are checked against node ephemeral-storage capacity, namespace `ResourceQuota`, and `LimitRange`.
- Kubex does not resize PVCs or manage `emptyDir` `sizeLimit`.

## Notes

- Use namespaced proactive policies when teams own their own namespaces.
- Container filtering happens before recommendation age and `KubexAutomation` checks, so summaries cover only containers owned by the policy.
- By default, only one same-kind proactive policy contributes to a workload. With `globalConfiguration.multiPolicyContainerRightsizingEnabled: true`, policies can contribute to separate container/resource targets; `PolicyEvaluation` resolves overlapping targets. See [Multi-Policy Container Rightsizing](./Multi-Policy-Container-Rightsizing.md).
- `Model` is included in default workload types. Use `spec.scope.workloadTypes: [Model]` when you want to restrict scope to KubeAI `Model` objects only. Recommendations and rollback state are stored on the `Model` owner, then inherited by model-owned pods.
- For cluster-scoped examples and field references, see [Cluster Proactive Policies](./Cluster-Proactive-Policies.md).
- EXPERIMENTAL: Recommendations can now include `gpu.gpuOverallOptimal`, which is applied as a proactive `requests.gpu` target. See the [GPU Sharing with KAI](./GPU-Sharing-with-KAI.md) guide for more information.
