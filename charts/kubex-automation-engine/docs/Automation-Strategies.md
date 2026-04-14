# Automation Strategies

`AutomationStrategy` defines how resizing is allowed to happen within a namespace.

Use it when a team owns its own namespace and should manage resize behavior locally.

For the cluster-scoped variant, see [Cluster Automation Strategies](./Cluster-Automation-Strategies.md).

Automation strategies control:

- which CPU and memory changes are allowed
- whether in-place resize is permitted
- whether eviction fallback is permitted
- which safety checks run before actions are executed

## Scope Mapping

- `ProactivePolicy` and `StaticPolicy` reference a namespaced `AutomationStrategy` in the same namespace.
- `ClusterProactivePolicy` and `ClusterStaticPolicy` reference a `ClusterAutomationStrategy`; those cluster-scoped relationships are documented in [Cluster Automation Strategies](./Cluster-Automation-Strategies.md).

## Field Reference

This page covers the configurable `spec` fields for namespaced `AutomationStrategy`. The cluster-scoped `ClusterAutomationStrategy` uses the same `spec` structure and defaults, but is documented separately in [Cluster Automation Strategies](./Cluster-Automation-Strategies.md).

Usage-level `floor` and `ceiling` values apply to all containers by default. Add `containers.<name>` under the same requests or limits block when a multi-container pod needs different bounds for specific containers.

| Field | Default | Description |
| --- | --- | --- |
| `spec.enablement` | `{}` | Parent object for enablement rules. |
| `spec.enablement.cpu.requests.downsize` | `true` | Allows reducing CPU requests. |
| `spec.enablement.cpu.requests.upsize` | `true` | Allows increasing CPU requests. |
| `spec.enablement.cpu.requests.setFromUnspecified` | `true` | Allows setting CPU requests when currently unset. |
| `spec.enablement.cpu.requests.floor` | none | Minimum CPU request target. |
| `spec.enablement.cpu.requests.ceiling` | none | Maximum CPU request target. |
| `spec.enablement.cpu.requests.containers.<name>.floor` | none | Container-specific CPU request minimum that overrides the usage-level floor for that container only. |
| `spec.enablement.cpu.requests.containers.<name>.ceiling` | none | Container-specific CPU request maximum that overrides the usage-level ceiling for that container only. |
| `spec.enablement.cpu.limits.downsize` | `true` | Allows reducing CPU limits. |
| `spec.enablement.cpu.limits.upsize` | `true` | Allows increasing CPU limits. |
| `spec.enablement.cpu.limits.setFromUnspecified` | `false` | Allows setting CPU limits when currently unset. |
| `spec.enablement.cpu.limits.floor` | none | Minimum CPU limit target. |
| `spec.enablement.cpu.limits.ceiling` | none | Maximum CPU limit target. |
| `spec.enablement.cpu.limits.containers.<name>.floor` | none | Container-specific CPU limit minimum that overrides the usage-level floor for that container only. |
| `spec.enablement.cpu.limits.containers.<name>.ceiling` | none | Container-specific CPU limit maximum that overrides the usage-level ceiling for that container only. |
| `spec.enablement.memory.requests.downsize` | `true` | Allows reducing memory requests. |
| `spec.enablement.memory.requests.upsize` | `true` | Allows increasing memory requests. |
| `spec.enablement.memory.requests.setFromUnspecified` | `true` | Allows setting memory requests when currently unset. |
| `spec.enablement.memory.requests.floor` | none | Minimum memory request target. |
| `spec.enablement.memory.requests.ceiling` | none | Maximum memory request target. |
| `spec.enablement.memory.requests.containers.<name>.floor` | none | Container-specific memory request minimum that overrides the usage-level floor for that container only. |
| `spec.enablement.memory.requests.containers.<name>.ceiling` | none | Container-specific memory request maximum that overrides the usage-level ceiling for that container only. |
| `spec.enablement.memory.limits.downsize` | `true` | Allows reducing memory limits. |
| `spec.enablement.memory.limits.upsize` | `true` | Allows increasing memory limits. |
| `spec.enablement.memory.limits.setFromUnspecified` | `true` | Allows setting memory limits when currently unset. |
| `spec.enablement.memory.limits.floor` | none | Minimum memory limit target. |
| `spec.enablement.memory.limits.ceiling` | none | Maximum memory limit target. |
| `spec.enablement.memory.limits.containers.<name>.floor` | none | Container-specific memory limit minimum that overrides the usage-level floor for that container only. |
| `spec.enablement.memory.limits.containers.<name>.ceiling` | none | Container-specific memory limit maximum that overrides the usage-level ceiling for that container only. |
| `spec.inPlaceResize.enabled` | `true` | Enables the in-place resize execution path. |
| `spec.inPlaceResize.containerRestart` | `false` | Allows in-place resize operations that require container restart. |
| `spec.podEviction.enabled` | `true` | Enables eviction-based fallback. |
| `spec.podEviction.retryPodDisruptionBudget` | `true` | Retries eviction when blocked by PDB. |
| `spec.safetyChecks.enablePauseUntilAnnotationCheck` | `true` | Blocks actions when pause annotations are present. |
| `spec.safetyChecks.enableResourceQuotaFilter` | `true` | Filters actions that would violate `ResourceQuota`. |
| `spec.safetyChecks.enableHpaFilter` | `true` | Filters actions for HPA-managed resources. |
| `spec.safetyChecks.enableVpaFilter` | `true` | Filters actions for VPA-managed resources. |
| `spec.safetyChecks.enableLimitRangeFilter` | `true` | Filters actions that violate `LimitRange` container rules. |
| `spec.safetyChecks.enablePodLimitRangeFilter` | `true` | Filters actions that violate pod-level `LimitRange` rules. |
| `spec.safetyChecks.minCpuChangePercent` | `5` | Ignores CPU changes below this threshold. |
| `spec.safetyChecks.minMemoryChangePercent` | `5` | Ignores memory changes below this threshold. |
| `spec.safetyChecks.minReadyDuration` | `10s` | Requires pods to be Ready for at least this duration. |
| `spec.safetyChecks.requireOwnerPodsReady` | `false` | Requires all pods in the owner workload to be Ready. |
| `spec.safetyChecks.respectWorkloadMaxUnavailable` | `true` | Prevents actions that exceed workload `maxUnavailable`. |
| `spec.safetyChecks.resizeRetryInterval` | `30s` | Requeue interval for temporarily blocked actions. |
| `spec.safetyChecks.requireNodeAllocatable` | `true` | Filters request increases that exceed node allocatable capacity. |
| `spec.safetyChecks.nodeCpuHeadroom` | `10%` | CPU headroom reserved before node allocatable checks. |
| `spec.safetyChecks.nodeMemoryHeadroom` | `200Mi` | Memory headroom reserved before node allocatable checks. |

## Example: Namespaced Strategy

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: AutomationStrategy
metadata:
  name: team-a-balanced
  namespace: team-a
spec:
  enablement:
    cpu:
      requests:
        downsize: true
        upsize: true
        setFromUnspecified: true
        floor: 100m
        ceiling: "4"
      limits:
        downsize: false
        upsize: true
        setFromUnspecified: false
        ceiling: "6"
    memory:
      requests:
        downsize: true
        upsize: true
        setFromUnspecified: true
        floor: 128Mi
        ceiling: 8Gi
        containers:
          api:
            floor: 256Mi
          worker:
            ceiling: 2Gi
      limits:
        downsize: false
        upsize: true
        setFromUnspecified: true
        floor: 256Mi
        ceiling: 12Gi
  inPlaceResize:
    enabled: true
    containerRestart: false
  podEviction:
    enabled: true
    retryPodDisruptionBudget: true
  safetyChecks:
    enablePauseUntilAnnotationCheck: true
    enableResourceQuotaFilter: true
    enableHpaFilter: true
    enableVpaFilter: true
    enableLimitRangeFilter: true
    enablePodLimitRangeFilter: true
    minCpuChangePercent: 10
    minMemoryChangePercent: 10
    minReadyDuration: 30s
    requireOwnerPodsReady: true
    respectWorkloadMaxUnavailable: true
    resizeRetryInterval: 1m
    requireNodeAllocatable: true
    nodeCpuHeadroom: 10%
    nodeMemoryHeadroom: 256Mi
```

## Related

- For cluster-scoped strategy examples and guidance, see [Cluster Automation Strategies](./Cluster-Automation-Strategies.md).
- For policies that reference this resource, see [Proactive Policies](./Proactive-Policies.md) and [Static Policies](./Static-Policies.md).
