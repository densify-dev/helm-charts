# Safety Controls Reference

Use this reference to interpret pre-checks and filters shown in logs, events, and recommendation payload summaries.

# Quick Links

- [Safety Controls Reference](#safety-controls-reference)
- [Quick Links](#quick-links)
  - [How To Read Outcomes](#how-to-read-outcomes)
  - [Pre-Checks](#pre-checks)
  - [Filters](#filters)
  - [Evaluation Order](#evaluation-order)
  - [Reading `failedChecks` and `appliedFilters`](#reading-failedchecks-and-appliedfilters)
  - [Related Guides](#related-guides)

---

## How To Read Outcomes

- `precheck` means execution is gated. A failed pre-check blocks the current resizing attempt.
- `filter` means action pruning. A filter removes one or more resize resource actions.

Where you will see the various pre-checks and filters:

- `rightsizing summary` contains the summary and logs `failedChecks` and `appliedFilters`
- Warning events with reason `PrecheckFailed` for failed pre-checks
- Recommendation payload summaries in `precheckSummary` and `filterSummary`

How to interpret `retry` in the context of this document:

- When a resize action will be retried, it means the condition that caused the pre-check failure is expected to resolve itself, for example when a pod becomes Ready.
- This is independent from `GlobalConfiguration.spec.rescanInterval`, which controls the regular interval for checking whether pods require resizing.

## Pre-Checks

| Runtime name | Stage | Controlled by | Behavior | Retry behavior | Typical message |
| --- | --- | --- | --- | --- | --- |
| `pod-terminating` | controller pod pre-check | always on (controller path) | Blocks if pod has `deletionTimestamp` | no retry from check itself | `pod is terminating` |
| `namespace-protected` | pre-check | `GlobalConfiguration.spec.protectedNamespacePatterns` | Blocks if pod namespace matches a protected namespace pattern | no retry from check itself | `namespace "<namespace>" is protected` |
| `pause-active` | pre-check | `spec.safetyChecks.enablePauseUntilAnnotationCheck` | Blocks when `rightsizing.kubex.ai/pause-until` is active (`infinite` or future RFC3339 time) | no retry from check itself | `automation paused by annotation` or `automation paused: <pause-reason>` |
| `resource-quota-exceeded` | pre-check | `spec.safetyChecks.enableResourceQuotaFilter` | Blocks if projected pod resources would exceed applicable `ResourceQuota` | no retry from check itself | `resource quota exceeded (ResourceQuota/<name>)` |
| `requests-exceed-limits` | final plan consistency pre-check | always on | Blocks when the filtered resize plan would leave a desired request above the effective desired/current limit | no retry from check itself | `desired request <x> exceeds limit <y> (container=<name>, resource=<resource>)` |
| `min-ready-duration-not-met` | final health pre-check | `spec.safetyChecks.minReadyDuration` | Blocks until pod has been Ready for at least `minReadyDuration` | retryable: uses remaining ready time when pod is Ready but elapsed Ready time is below `spec.safetyChecks.minReadyDuration`; uses `spec.safetyChecks.resizeRetryInterval` when pod is not Ready or ready transition time is unknown | `pod not ready` or `pod ready for ... (<...)` |
| `owner-pods-not-ready` | final health pre-check | `spec.safetyChecks.requireOwnerPodsReady` | Blocks when any owner pod is not Ready | retryable: uses `spec.safetyChecks.resizeRetryInterval` | `owner pod <name> not ready` |
| `max-unavailable-exceeded` | final health pre-check | `spec.safetyChecks.respectWorkloadMaxUnavailable` | Blocks when another unavailable pod would exceed owner workload `maxUnavailable` | retryable: uses `spec.safetyChecks.resizeRetryInterval` | `maxUnavailable <n> exceeded` |
| `too-many-requests` | execution retry guard | `spec.podEviction.retryPodDisruptionBudget` | Blocks when eviction is rejected with API `429 TooManyRequests`, for example PodDisruptionBudget rejection or API throttling | retryable when enabled: requeues using `spec.safetyChecks.resizeRetryInterval` | `resize blocked by too many requests (...)` |
| `recommendation-too-old` | proactive recommendation guard | `ProactivePolicy.spec.safetyChecks.maxAnalysisAgeDays` / `ClusterProactivePolicy.spec.safetyChecks.maxAnalysisAgeDays` | Strips out recommendations coming from Kubex when they are too old | not a pod requeue check; summary guard | `recommendation too old` |

## Filters

| Runtime name | Stage | Controlled by | Behavior | Targets / metadata | Typical message |
| --- | --- | --- | --- | --- | --- |
| `no-resize-needed` | plan build | always on | Marks resources where desired equals current and no action is needed | target list only | n/a (summary marker) |
| `automation-strategy-disabled` | action filter | `spec.enablement.*` fields in the referenced strategy | Removes actions disallowed by direction such as `upsize`, `downsize`, or `setFromUnspecified` | filter metadata may include `direction` | `upsize disabled`, `downsize disabled`, or `setFromUnspecified disabled` |
| `change-below-threshold` | pod action filter | `spec.safetyChecks.minCpuChangePercent`, `spec.safetyChecks.minMemoryChangePercent` | Removes actions whose percent delta is below threshold | target list only | `delta ... below minimum ...` |
| `hpa-resource-managed` | pod action filter | `spec.safetyChecks.enableHpaFilter` | Removes actions for CPU or memory managed by a matching HPA, including KEDA-managed HPA handling | filter metadata may include `source=hpa` and `hpaMode` | `HPA targets <resource>` |
| `vpa-resource-managed` | pod action filter | `spec.safetyChecks.enableVpaFilter` | Removes actions for resources constrained by a matching VPA | target list only | `VPA constrains <resource>` |
| `node-capacity-insufficient` | pod action filter | `spec.safetyChecks.requireNodeAllocatable`, `spec.safetyChecks.nodeCpuHeadroom`, `spec.safetyChecks.nodeMemoryHeadroom` | Removes request increase actions when remaining allocatable capacity, after headroom reservation, is insufficient | target list only | `remaining <x> < delta <y>` |
| `limit-range-violated` | policy recommendation filter | `spec.safetyChecks.enableLimitRangeFilter` | Removes recommendation actions that violate namespace `LimitRange` container min or max | filter metadata may include `name` | `desired ... below ... (LimitRange/<name>)` or `desired ... exceeds ... (LimitRange/<name>)` |
| `pod-limit-range-violated` | pod action filter | `spec.safetyChecks.enablePodLimitRangeFilter` | Removes actions when resulting pod-level totals violate `LimitRange` pod min or max | filter metadata may include `name` | `total desired ... requests below ... (LimitRange/<name>)` or `total desired ... limits exceeds ... (LimitRange/<name>)` |
| `kubex-automation-disabled` | proactive recommendation filter | `GlobalConfiguration.spec.respectKubexAutomation` | Removes recommendations coming from Kubex with `KubexAutomation=false` | target list only | n/a (summary marker) |

## Evaluation Order

1. Build candidate actions from selected recommendations.
2. Apply `automation-strategy-disabled`.
3. Run early pre-checks: `pod-terminating`, `namespace-protected`, optional `pause-active`, optional `resource-quota-exceeded`.
4. Apply pod action filters: `change-below-threshold`, `hpa-resource-managed`, `vpa-resource-managed`, `node-capacity-insufficient`, `pod-limit-range-violated`.
5. Run final non-retryable plan consistency checks: `requests-exceed-limits`.
6. Run final retryable health checks: `min-ready-duration-not-met`, `owner-pods-not-ready`, `max-unavailable-exceeded`.
7. Execute in-place resize or eviction if actions remain.

Notes:

- Workload policy recommendation generation also applies `limit-range-violated` before owner annotations are written.
- The webhook evaluation path runs `namespace-protected`, `pause-active`, and `resource-quota-exceeded`.
- `pod-terminating` and the final retryable health checks are controller-side.

## Reading `failedChecks` and `appliedFilters`

- `failedChecks` contains check failures with `name`, optional `message`, and optional `metadata`.
- `appliedFilters` contains pruned actions with `name`, optional filter `metadata`, and `targets` with `container`, `usage`, and `resource`.

Example interpretation:

- `{"name":"min-ready-duration-not-met","message":"pod not ready"}` in `failedChecks` means execution is blocked for now and retried.
- `{"name":"resource-quota-exceeded","message":"resource quota exceeded (ResourceQuota/team-quota)","metadata":{"name":"team-quota"}}` in `failedChecks` identifies the specific blocking quota.
- `{"name":"hpa-resource-managed","targets":[{"container":"app","usage":"requests","resource":"cpu"}]}` in `appliedFilters` means that resize action was removed because HPA controls that resource.

## Related Guides

- For cluster-wide operating controls, see [Advanced Configuration](./Advanced-Configuration.md).
- For strategy field reference, see [Automation Strategies](./Automation-Strategies.md) and [Cluster Automation Strategies](./Cluster-Automation-Strategies.md).
- For recommendation freshness on policies, see [Proactive Policies](./Proactive-Policies.md) and [Cluster Proactive Policies](./Cluster-Proactive-Policies.md).
- For debugging blocked actions, see [Troubleshooting](./Troubleshooting.md).
