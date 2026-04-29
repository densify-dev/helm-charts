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
| `spec.scheduling` | `{}` | Parent object for scheduling-based allow and block windows. |
| `spec.scheduling.inclusionWindows[]` | none | Windows when resizing is allowed. When at least one inclusion window exists, resizing is allowed only inside one of them. |
| `spec.scheduling.inclusionWindows[].name` | none | Optional label used in logs and summaries. |
| `spec.scheduling.inclusionWindows[].timezone` | `UTC` | IANA timezone used for weekday and time evaluation. |
| `spec.scheduling.inclusionWindows[].weekdays[]` | all days | Restricts the window to specific weekdays such as `Monday` or `Mon`. |
| `spec.scheduling.inclusionWindows[].start` | `00:00` | Inclusive local start time in `HH:MM` 24-hour format. If omitted, the window begins at the start of the day. |
| `spec.scheduling.inclusionWindows[].end` | `24:00` | Exclusive local end time in `HH:MM` 24-hour format. If omitted, the window ends at the end of the day. Supports `24:00` to represent the end of the day. |
| `spec.scheduling.exclusionWindows[]` | none | Windows when resizing is blocked. Exclusion windows always take precedence over inclusion windows. |
| `spec.scheduling.exclusionWindows[].name` | none | Optional label used in logs and summaries. |
| `spec.scheduling.exclusionWindows[].timezone` | `UTC` | IANA timezone used for weekday and time evaluation. |
| `spec.scheduling.exclusionWindows[].weekdays[]` | all days | Restricts the window to specific weekdays such as `Friday` or `Fri`. |
| `spec.scheduling.exclusionWindows[].start` | `00:00` | Inclusive local start time in `HH:MM` 24-hour format. If omitted, the window begins at the start of the day. |
| `spec.scheduling.exclusionWindows[].end` | `24:00` | Exclusive local end time in `HH:MM` 24-hour format. If omitted, the window ends at the end of the day. Supports `24:00` to represent the end of the day. |
| `spec.safetyChecks.enablePauseUntilAnnotationCheck` | `true` | Blocks actions when pause annotations are present. |
| `spec.safetyChecks.enableResourceQuotaFilter` | `true` | Filters actions that would violate `ResourceQuota`. |
| `spec.safetyChecks.enableHpaFilter` | `true` | Filters actions for HPA-managed resources. |
| `spec.safetyChecks.enableVpaFilter` | `true` | Filters actions for VPA-managed resources. |
| `spec.safetyChecks.enableLimitRangeFilter` | `true` | Filters actions that violate `LimitRange` container rules. |
| `spec.safetyChecks.enablePodLimitRangeFilter` | `true` | Filters actions that violate pod-level `LimitRange` rules. |
| `spec.safetyChecks.retainGuaranteedQOS` | `false` | Keeps Guaranteed QoS pods at request=limit by treating limits as the source of truth for CPU and memory when enabled. |
| `spec.safetyChecks.minCpuChangePercent` | `5` | Ignores CPU changes below this threshold. |
| `spec.safetyChecks.minMemoryChangePercent` | `5` | Ignores memory changes below this threshold. |
| `spec.safetyChecks.minReadyDuration` | `10s` | Requires pods to be Ready for at least this duration. |
| `spec.safetyChecks.requireOwnerPodsReady` | `false` | Requires all pods in the owner workload to be Ready. |
| `spec.safetyChecks.respectWorkloadMaxUnavailable` | `true` | Prevents actions that exceed workload `maxUnavailable`. |
| `spec.safetyChecks.resizeRetryInterval` | `30s` | Requeue interval for temporarily blocked actions. |
| `spec.safetyChecks.requireNodeAllocatable` | `true` | Filters request increases that exceed node allocatable capacity. |
| `spec.safetyChecks.nodeCpuHeadroom` | `10%` | CPU headroom reserved before node allocatable checks. |
| `spec.safetyChecks.nodeMemoryHeadroom` | `200Mi` | Memory headroom reserved before node allocatable checks. |

## Scheduling Windows

`spec.scheduling` lets platform teams constrain when cluster-scoped proactive automation is allowed to execute.

- `inclusionWindows` define allowed times. If multiple inclusion windows are defined, they are evaluated with OR logic (automation is allowed if it matches ANY inclusion window). Inclusion windows may overlap.
- `exclusionWindows` define blocked times and always override inclusion windows.
- If neither list is set, scheduling does not restrict automation.
- If any inclusion window is defined, automation is allowed only while the current time matches at least one inclusion window.
- `start` is inclusive and `end` is exclusive.
- If `start` or `end` are omitted, they default to `00:00` and `24:00` respectively, allowing for easy "all day" configuration.
- Windows are evaluated in the window's local IANA timezone specified in the `timezone` field.
- Overnight windows are supported. For example, `22:00` to `06:00` spans midnight. `24:00` is supported for exclusive end times.

When scheduling blocks a proactive resize, the controller keeps the recommendation pending and retries when the next allowed window opens.

## Helm Mapping

The current chart can generate `ClusterAutomationStrategy` resources from `policy.policies`, but it does not render scheduling fields from Helm values.

For scheduling-controlled cluster automation:

- Create or manage the `ClusterAutomationStrategy` manifest directly.
- Reference that strategy name from a Helm-managed or manually managed `ClusterProactivePolicy`.

## Guaranteed QoS Behavior

When `spec.safetyChecks.retainGuaranteedQOS` is enabled:

- The behavior applies only to pods that are currently in the Kubernetes `Guaranteed` QoS class.
- For CPU and memory, desired limits are treated as the source of truth.
- Matching request actions are aligned to the same desired value as limits so `requests == limits` remains true.
- If a limit action exists but no request action exists, the controller can add a matching request action to preserve `Guaranteed` QoS.

When this toggle is disabled (default), requests and limits are handled independently by recommendation and enablement logic, and a pod can move away from `Guaranteed` QoS.

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
  scheduling:
    inclusionWindows:
      - name: overnight-maintenance
        timezone: America/New_York
        weekdays:
          - Mon
          - Tue
          - Wed
          - Thu
          - Fri
        start: "22:00"
        end: "06:00"
    exclusionWindows:
      - name: monday-freeze
        timezone: America/New_York
        weekdays:
          - Mon
        start: "00:00"
        end: "02:00"
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
