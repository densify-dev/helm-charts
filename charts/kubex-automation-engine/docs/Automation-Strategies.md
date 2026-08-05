# Automation Strategies

> Experimental: GPU/KAI-related fields in this resource are subject to breaking changes. When using them, set `spec.experimental.gpuKaiContract: v1alpha1-2026-07`.

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
| `spec.enablement.overrideScheduler` | `none` | EXPERIMENTAL. Selects GPU mutation mode for GPU actions. Valid values: `none`, `kai`. |
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
| `spec.enablement.gpu.requests.downsize` | `false` | EXPERIMENTAL. Allows reducing GPU requests. |
| `spec.enablement.gpu.requests.upsize` | `false` | EXPERIMENTAL. Allows increasing GPU requests. |
| `spec.enablement.gpu.requests.setFromUnspecified` | `false` | EXPERIMENTAL. Allows setting GPU requests when currently unset. |
| `spec.enablement.gpu.requests.floor` | none | EXPERIMENTAL. Minimum GPU request target. |
| `spec.enablement.gpu.requests.ceiling` | none | EXPERIMENTAL. Maximum GPU request target. |
| `spec.enablement.gpu.requests.containers.<name>.floor` | none | EXPERIMENTAL. Container-specific GPU request minimum that overrides the usage-level floor for that container only. |
| `spec.enablement.gpu.requests.containers.<name>.ceiling` | none | EXPERIMENTAL. Container-specific GPU request maximum that overrides the usage-level ceiling for that container only. |
| `spec.kai.queue` | `kubex-unlimited-gpu-queue` | EXPERIMENTAL. Default KAI queue label applied for KAI GPU admission mutation. |
| `spec.kai.setQueueWhenSpecified` | `false` | EXPERIMENTAL. Allows strategy queue value to overwrite an existing `kai.scheduler/queue` label. |
| `spec.kai.vllm` | none | EXPERIMENTAL. Enables admission-time vLLM tuning for KAI GPU-sharing workloads. Requires `spec.experimental.gpuKaiContract`. |
| `spec.kai.vllm.gpuMemoryUtilizationBufferPercent` | `0` | EXPERIMENTAL. Reduces vLLM `--gpu-memory-utilization` below admitted `gpu-fraction` by this percent. Effective target = `gpuFraction * (1 - bufferPercent/100)`. |
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
| `spec.safetyChecks.enableVpaFilter` | `true` | Filters actions when a VPA is actively managing the resource (has recommendations and updateMode enabled). |
| `spec.safetyChecks.blockResizeOnVpaControlledResources` | `false` | Filters actions for any resource declared in a VPA resourcePolicy, even if the VPA is Off or has no recommendations. This setting is only evaluated after `enableVpaFilter=true` passes, so it is more defensive than `enableVpaFilter`. |
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

## VPA Filter Behavior

Two complementary VPA filters help avoid conflicts between Kubex automation and Vertical Pod Autoscalers:

### enableVpaFilter (default: true)

Filters actions when a VPA is **actively managing** the resource. This requires all of:
- VPA `updateMode` is not `Off` (i.e., `Auto`, `Recreate`, or `Initial`)
- VPA has an active recommendation with status `RecommendationProvided=True`
- The resource dimension (e.g., `cpu.requests`) appears in the VPA's `containerRecommendations`

**Use case:** Prevent conflicts when VPA is actively recommending and applying changes. This is the default safe behavior that defers to VPA when it's doing work.

### blockResizeOnVpaControlledResources (default: false)

Filters actions for resources **declared** in a VPA `resourcePolicy`, regardless of whether the VPA is active. This check is only evaluated when `enableVpaFilter=true`. It checks only:
- The resource is listed in `resourcePolicy.containerPolicies[].controlledResources`
- The usage type (requests/limits) matches `controlledValues` (defaults to both)

Does **not** check:
- VPA `updateMode` (blocks even when `Off`)
- Recommendation status (blocks even when no recommendations exist)
- Whether VPA is actively applying changes

**Use case:** Reserve resources for future VPA management, or ensure strict non-interference when VPA ownership is declared but the VPA may be temporarily disabled or not yet providing recommendations.

### Comparison

| Scenario | enableVpaFilter | blockResizeOnVpaControlledResources |
| --- | --- | --- |
| VPA in `Auto` mode with active recommendations | Blocks | Blocks |
| VPA in `Off` mode with resourcePolicy declared | Allows | Blocks |
| VPA in `Auto` mode but no recommendations yet | Allows | Blocks |
| VPA in `Initial` mode after first recommendation | Allows | Blocks (if resourcePolicy declared) |
| No matching VPA | Allows | Allows |

**Note:** `blockResizeOnVpaControlledResources` is ignored unless `enableVpaFilter=true` is enabled.

## Scheduling Windows

`spec.scheduling` lets you control when the controller is allowed to execute resize actions.

- `inclusionWindows` define allowed times. If multiple inclusion windows are defined, they are evaluated with OR logic (automation is allowed if it matches ANY inclusion window). Inclusion windows may overlap.
- `exclusionWindows` define blocked times and always override inclusion windows.
- If neither list is set, scheduling does not restrict automation.
- If any inclusion window is defined, automation is allowed only while the current time matches at least one inclusion window.
- `start` is inclusive and `end` is exclusive.
- If `start` or `end` are omitted, they default to `00:00` and `24:00` respectively, allowing for easy "all day" configuration.
- Windows are evaluated in the window's local IANA timezone specified in the `timezone` field.
- Overnight windows are supported. For example, `22:00` to `02:00` spans midnight.
- `weekdays` accepts full and short names such as `Monday`, `Mon`, `Thursday`, or `Thu`.

Validation notes:

- `timezone` must be a valid IANA timezone such as `UTC`, `Europe/London`, or `America/New_York`.
- `start` and `end` must use 24-hour `HH:MM` format. `24:00` is supported for exclusive end times.
- `start` and `end` cannot be the same value, unless they are both omitted.

When a proactive resize is blocked by scheduling, the controller keeps the recommendation pending and retries when a future allowed window opens.

## KAI vLLM tuning

When `spec.kai.vllm` is set, pod admission keeps KAI `gpu-fraction` as source value and tunes vLLM `--gpu-memory-utilization` from it.

Formula:

- `effective = gpuFraction * (1 - bufferPercent/100)`
- Example: `gpuFraction=0.5` and `gpuMemoryUtilizationBufferPercent=10` => `0.45`

Admission behavior:

- applies only to KAI GPU request admission mutation
- mutates container `args` in place for detected vLLM containers
- replaces existing `--gpu-memory-utilization=<value>`
- replaces existing split form `--gpu-memory-utilization <value>`
- appends flag when missing
- never leaves duplicate `--gpu-memory-utilization` args behind

Example:

```yaml
spec:
  experimental:
    gpuKaiContract: v1alpha1-2026-07
  kai:
    vllm:
      gpuMemoryUtilizationBufferPercent: 10
```

## Helm Mapping

Scheduling is part of the `AutomationStrategy` and `ClusterAutomationStrategy` CRD surface, but the current chart does not map `policy.policies.<name>.scheduling` into generated `ClusterAutomationStrategy` resources.

For Helm-based installs, that means:

- Use `policy.policies` for the Helm-managed subset of strategy settings.
- Manage `AutomationStrategy` or `ClusterAutomationStrategy` manifests directly when you need scheduling windows.
- Point Helm-managed policy scopes at that externally managed strategy by name when needed.

## Guaranteed QoS Behavior

When `spec.safetyChecks.retainGuaranteedQOS` is enabled:

- The behavior applies only to pods that are currently in the Kubernetes `Guaranteed` QoS class.
- For CPU and memory, desired limits are treated as the source of truth.
- Request values are automatically set to match limit values so `requests == limits` remains true.
- If a limit action exists but no request action exists, the controller can add a matching request action to preserve `Guaranteed` QoS.

When this toggle is disabled (default), requests and limits are handled independently by recommendation and enablement logic, and a pod can move away from `Guaranteed` QoS.

Note: A pod is in the `Guaranteed` QoS class only when ALL containers have `requests == limits` for BOTH CPU and memory. If a container has CPU request=limit but memory request≠limit, the pod is `Burstable`, not `Guaranteed`, and this behavior does not activate.

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
  scheduling:
    inclusionWindows:
      - name: weekday-business-hours
        timezone: Europe/London
        weekdays:
          - Mon
          - Tue
          - Wed
          - Thu
          - Fri
        start: "09:00"
        end: "18:00"
    exclusionWindows:
      - name: friday-freeze
        timezone: Europe/London
        weekdays:
          - Fri
        start: "16:00"
        end: "23:59"
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
