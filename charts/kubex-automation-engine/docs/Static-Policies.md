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
| `spec.scope.workloadTypes` | `[Deployment, StatefulSet, CronJob, Rollout, Job, AnalysisRun, DaemonSet, Model]` | Workload kinds this policy applies to. Default excludes `StrimziPodSet` only. |
| `spec.scope.containers` | all automatable containers | Exact container names. Duplicates, `"*"`, and invalid Kubernetes container names are rejected. Unknown names are allowed. |
| `spec.resources.containers` | none | Map of container names to requests and limits. Use `"*"` for all scoped containers. |
| `spec.weight` | `0` | Higher weight takes precedence when same-kind policies compete. |
| `spec.automationStrategyRef.name` | none | Required namespaced strategy name. |

## `ClusterStaticPolicy.spec`

| Field | Default | Description |
| --- | --- | --- |
| `spec.scope.labelSelector` | none | Kubernetes label selector for matching workloads. |
| `spec.scope.workloadTypes` | `[Deployment, StatefulSet, CronJob, Rollout, Job, AnalysisRun, DaemonSet, Model]` | Workload kinds this policy applies to. Default excludes `StrimziPodSet` only. |
| `spec.scope.namespaceSelector.operator` | none | Namespace selector operator: `In` or `NotIn`. |
| `spec.scope.namespaceSelector.values` | none | Namespace patterns to include or exclude (supports `*` wildcards, e.g. "prod-*"). Wildcard patterns must be enclosed in double quotes. |
| `spec.scope.containers` | all automatable containers | Exact container names. Empty means all automatable containers. |
| `spec.resources.containers` | none | Map of container names to requests and limits. Use `"*"` for all scoped containers. |
| `spec.weight` | `0` | Higher weight takes precedence when same-kind policies compete. |
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
    containers:
      - api
      - metrics
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
    labelSelector:
      matchLabels:
        tier: database
    workloadTypes:
      - StatefulSet
    namespaceSelector:
      operator: In
      values:
        - "prod-*"
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

## GPU requests and limits

Both static policy kinds accept logical `gpu` values under `requests` and `limits` for native NVIDIA resources, KAI HAMi-core, and KAI NvFractions.

For both `StaticPolicy` and `ClusterStaticPolicy`, each container entry with `requests.gpu` must also specify `limits.gpu` in that same entry. This includes wildcard `"*"` entries. A limit in another entry or policy does not satisfy this requirement. Existing request-only GPU policies must add a limit before upgrading. If a legacy policy produces an incomplete selected GPU pair, validation fails before CPU or memory actions are built. This blocks the entire resize plan immediately after upgrading, even when GPU actions are disabled on the strategy, until the selected pair is corrected.

Limit-only entries remain accepted, but GPU execution requires a complete selected request/limit pair per container. Both values must be positive. Admission remains backend-neutral and accepts unequal positive pairs; the controller checks backend constraints after policy selection and bounds.

- Native NVIDIA requires equal logical targets before rounding up to whole GPUs and writing equal `nvidia.com/gpu` requests and limits. For example, request `"1.2"` and limit `"1.2"` produce `2` for both. Unequal logical targets are rejected even if they would round to the same integer.
- HAMi-core requires equal targets and writes that fraction to both `gpu-fraction` and `gpu-fraction.limit`.
- NvFractions supports separate requests and limits satisfying `0 < request <= limit < 1`.

With KAI NvFractions, these values are proportions of one GPU's memory, not Kubernetes extended-resource limits or compute guarantees. The request reserves memory for scheduling; memory above it, up to the limit, is opportunistic.

This NvFractions setup is illustrative and non-executable pending release validation. KAI `vX.Y.Z` is an unresolved placeholder; compatibility with GPU Fractioning `0.1.9` has not been validated. Follow [GPU Sharing with KAI](./GPU-Sharing-with-KAI.md) before applying policies.

For example, on a policy targeting a single GPU container named `app`:

```yaml
spec:
  resources:
    containers:
      app:
        requests:
          gpu: "0.5"
        limits:
          gpu: "0.8"
```

The referenced strategy must explicitly set `kai.gpuSharingMode: NvFractions` and `enablement.overrideScheduler: kai`. Configure requests and limits under `enablement.gpu`; every direction is disabled by default. The pair is atomic: every changing member must allow its direction or neither GPU member changes. An unchanged member needs no direction enabled but must remain explicit. Unrelated CPU and memory changes can still proceed. Use `inPlaceResize.enabled: false` and `podEviction.enabled: true` because enforcement takes effect when the replacement container starts. See the [strategy example](./GPU-Sharing-with-KAI.md#proactive-starter).

- The effective pair must satisfy `0 < request <= limit < 1`; explicit portion limits allow at most five decimal places. Use a strategy ceiling such as `"0.99999"`, not `"1"`.
- Neither omitted target falls back to the other member, the live Pod, or the workload template. An incomplete selected pair blocks the entire resize plan, including CPU and memory changes, until corrected.
- Keep both targets explicit even when changing only one member. For example, to change request `"0.4"` to `"0.5"` while retaining limit `"0.8"`, select request `"0.5"` and limit `"0.8"`.
- Selecting equal request and limit targets removes a previous explicit NvFractions portion limit to express a fixed allocation. A selected limit below the request is rejected.
- Canonical pod inputs are `gpu-fraction` and `gpu-fraction.limit`. The translated `kai.scheduler/container.<name>.gpu-memory.portion.limit` key remains compatible. Do not use annotation names as resource keys or emit both limit forms.
- Absolute-memory, compute-mode, and multi-device KAI sharing automation are not supported.

## Notes

- Use static policies when exact values matter more than recommendation-driven tuning.
- `resources.containers."*"` applies a default to every scoped container, and named values override wildcard values for the same resource.
- When `scope.containers` is set, entries for other containers are removed and wildcard values expand into each listed name.
- Container targets include regular containers and native sidecar init containers (`restartPolicy: Always`). One-shot init containers are not automated.
- `Model` is included in default workload types. Use `spec.scope.workloadTypes: [Model]` when you want to restrict scope to KubeAI `Model` objects only. Recommendations and rollback state are stored on the `Model` owner, then inherited by model-owned pods.
- By default, only one same-kind static policy contributes to a workload. With `globalConfiguration.multiPolicyContainerRightsizingEnabled: true`, separate container/resource targets can come from different policies; `PolicyEvaluation` resolves overlapping targets. See [Multi-Policy Container Rightsizing](./Multi-Policy-Container-Rightsizing.md).
