# Cluster Automation Strategies

`ClusterAutomationStrategy` defines how resizing is allowed to happen for cluster-scoped policy flows.

Use it when a platform team wants one reusable resize behavior that can be referenced by `ClusterProactivePolicy` and `ClusterStaticPolicy` across multiple namespaces.

For the namespaced variant, see [Automation Strategies](./Automation-Strategies.md).

## Reference Rules

- `ClusterProactivePolicy` references a `ClusterAutomationStrategy`.
- `ClusterStaticPolicy` references a `ClusterAutomationStrategy`.
- Helm can generate `ClusterAutomationStrategy` resources from `policy.policies`, but these CRs can also be managed directly with manifests or GitOps.

## Field Reference

`ClusterAutomationStrategy.spec` uses the same field structure and defaults as the namespaced `AutomationStrategy`:

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

## Example

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterAutomationStrategy
metadata:
  name: platform-conservative
spec:
  enablement:
    cpu:
      requests:
        downsize: false
        upsize: true
        setFromUnspecified: true
        floor: 250m
        ceiling: "8"
    memory:
      requests:
        downsize: false
        upsize: true
        setFromUnspecified: true
        floor: 512Mi
        ceiling: 16Gi
        containers:
          api:
            floor: 1Gi
          worker:
            ceiling: 8Gi
      limits:
        downsize: false
        upsize: true
        setFromUnspecified: true
  inPlaceResize:
    enabled: true
    containerRestart: false
  podEviction:
    enabled: false
  safetyChecks:
    enableResourceQuotaFilter: true
    enableHpaFilter: true
    enableVpaFilter: true
    minCpuChangePercent: 15
    minMemoryChangePercent: 15
    minReadyDuration: 1m
    respectWorkloadMaxUnavailable: true
    requireNodeAllocatable: true
    nodeCpuHeadroom: 15%
    nodeMemoryHeadroom: 512Mi
```

## Notes

- Prefer cluster strategies when one platform-owned policy model should apply across many namespaces.
- Use namespaced `AutomationStrategy` instead when teams should own and evolve resize behavior independently inside their own namespaces.
- For Helm-managed mappings and limits, see [Policy Configuration](./Policy-Configuration.md).
