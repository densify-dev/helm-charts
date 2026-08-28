# Changelog

All notable changes to the Kubex Automation Engine Helm chart will be documented in this file.

## [1.11.2] - 2026-08-27

### Changed
- Proposal synchronization now handles every supported `rightsizing.kubex.ai/v1alpha1` custom resource, including `ObjectPatch` and `ClusterObjectPatch` resources and both namespaced and cluster-scoped objects.
- Compaction scheduler and descheduler support objects are enabled by default, so `ClusterCompactionPolicy` setup no longer needs extra Helm values.

---

## [1.11.1] - 2026-08-26

### Fixed
- KAI vLLM GPU memory tuning now accounts for HAMi's visible GPU memory instead of the raw device total, avoiding an incorrect double application of the GPU fraction on HAMi-backed clusters.
- vLLM GPU memory tuning is now applied correctly in mixed resize plans and when the selected GPU recommendation is already applied (no-op resizes).

---

## [1.11.0] - 2026-08-19

### Added
- `ContainerArgsPolicy` for managing named container arguments during admission and pod replacement, with support for add, update, and remove operations to support GPU vLLM tuning.
- Policy snapshots now include all supported `rightsizing.kubex.ai` custom resources, including GPU, compaction, object patch, and container argument policies.
- Cluster names can be sourced from a ConfigMap or Secret instead of being specified directly in chart values, supporting installations from `kubex-automation-stack`.

### Changed
- Policy evaluation now includes `PodAffinityPolicy` resources.
- Compaction scheduler and descheduler components are enabled by default for compaction policy support.
- Pre-delete cleanup now removes finalizers from every supported `rightsizing.kubex.ai` custom resource.

---

## [1.10.0] - 2026-08-11

### Added
- ObjectPatch and ClusterObjectPatch resources for applying controlled JSON merge patches to Kubernetes objects.
- Cluster compaction policies for bin-packing workloads with Kubex-managed or external schedulers, per-policy descheduler settings, and eviction-loop suppression.

### Changed
- Resource and workload handling now preserves more Kubernetes state across resize, rollback, and controller-managed reconciliation paths.
- Updated the KAI GPU-sharing guide for KAI v0.17.0 and optional HAMi-core 1.1.0 integration.

### Fixed
- In-place resize rollback monitoring now records the refreshed post-resize Pod state.
- Compaction eviction convergence now reacts when replacement Pods are assigned to nodes.

---

## [1.9.1] - 2026-08-06

### Fixed
- Rollback no longer gets stuck indefinitely when there's nothing to roll back to; it now stops with a clear error instead of looping forever.
- Rollback now correctly restores the last known-good configuration, instead of reapplying the broken one that triggered it.
- Fixed a safety check that could permanently block recovery for single-replica workloads.
- A resize that triggered a rollback can no longer be immediately reapplied by another policy while the workload is recovering.
- Improved reliability of rollback handling for workloads with deleted or missing owners.

---

## [1.9.0] - 2026-07-28

### Breaking
- **[GPU policies renamed](./BREAKING.md#2026-07-21-gpu-reactive-policy-rename)**: `GpuRebalancingPolicy` and `ClusterGpuRebalancingPolicy` are renamed to `GpuReactivePolicy` and `ClusterGpuReactivePolicy`. Kubernetes doesn't support renaming a CRD in place, so existing GPU policies need to be recreated under the new names after upgrading - see the linked migration steps before upgrading.

### Added
- The pod rightsizing webhook can now optionally run at the beginning and end of admission, so it works correctly alongside the KAI GPU-sharing scheduler's own webhook. This is off by default and only needed if you're running other resource-mutating webhooks alongside Kubex.
- Pods now get a `rightsizing.kubex.ai/automation-constraints` annotation explaining why a recommendation couldn't be fully applied (for example, a resource being managed by an HPA, or automation being disabled), including which containers and resources were affected.

### Changed
- The default timeout for requests to the Kubex API increased from 30 seconds to 60 seconds.

---

## [1.8.0] - 2026-07-22

### Breaking
- **[GPU enablement defaults and experimental contract](./BREAKING.md#2026-07-20---gpu-enablement-defaults-and-experimental-contract)**: GPU request actions now default to disabled. `spec.enablement.gpu.requests.downsize`, `.upsize`, and `.setFromUnspecified` changed from `true` to `false`. The GPU/KAI experimental contract changed to `v1alpha1-2026-07`; the previous contract is no longer accepted. Affects `AutomationStrategy`, `ClusterAutomationStrategy`, `GpuRebalancingPolicy`, `ClusterGpuRebalancingPolicy`, and `GpuConsolidationPolicy`.
  - After upgrading the CRDs, update `spec.experimental.gpuKaiContract` from `v1alpha1-2026-04` to `v1alpha1-2026-07` in every affected resource.
  - For `AutomationStrategy`/`ClusterAutomationStrategy`, explicitly set each desired GPU action under `spec.enablement.gpu.requests` to `true` if you rely on GPU request resizing. GPU policy kinds only need the contract update.
  - Reapply affected resources after making these changes.

### Added
- Rollback monitoring now reopens automatically when a newer replacement pod appears carrying the same recommendation and matching resources, so a pod recreated by eviction, in-place resize, or a manual restart resumes being tracked instead of starting a brand-new monitoring turn.
- `RollbackPolicy`/`ClusterRollbackPolicy` gain `spec.enableMonitoringReopen` (default `true`) to opt out of this reopen behavior for a given policy.
- Manifest-level resource sizing is now reported to the Kubex backend, giving visibility into a workload's declared (manifest) resources alongside its live/adopted values.

---

## [1.7.0] - 2026-07-14

### Added
- Secondary/DR cluster mode for recommendation consumption from a primary cluster.

---

## [1.6.0] - 2026-07-06

### Added
- KubeAI `Model` workload support for automated rightsizing and rollback tracking.
- GPU-sharing tuning controls for KAI-based automation strategies.
- Container-level skip controls for rightsizing, so specific containers can be excluded without blocking resize actions for the rest of the pod.

### Changed
- Default policy evaluation now includes KubeAI `Model` workloads when `workloadTypes` is not set.
- VPA-aware resize handling is more consistent across live workloads.

### Fixed
- Helm uninstall reliability for charts using rightsizing resources.
- GPU rightsizing and validation stability.
- In-place resized pods now retain the pod-rightsizing-info annotation so live pod state stays observable.

---

## [1.5.0] - 2026-06-23

### Added
- KubeAI `Model` workload support, including owner-scoped recommendation and rollback state handling.
- KAI/vLLM tuning controls for GPU-sharing automation strategies.

### Changed
- Default policy workload scope now includes KubeAI `Model` objects when `workloadTypes` is omitted.
- Rollback monitoring now enforces adoption-threshold behavior more consistently.
- Agentic Proposal sync remains opt-in through `GlobalConfiguration` and is disabled by default.

### Fixed
- Helm uninstall reliability by aligning the pre-delete cleanup hook permissions with the rightsizing resources it patches.

---

## [1.4.0] - 2026-06-11

### Added
- Initial formal release of the integration with the KAI scheduler for rightsizing fractional GPUs

### Changed
- KAI documentation, examples, and release notes were updated for the `v1.4.0` release

---

## [1.3.1] - 2026-06-09

### Changed
- Default policy evaluation now gives `RollbackPolicy` and `ClusterRollbackPolicy` the highest precedence.

---

## [1.3.0] - 2026-06-04

### Added
- Introduced Rollback automation so clusters can now use the rollback state machine in live environments.

### Changed
- Rollback owner/runtime handling and e2e fixtures were updated to support the new rollback flow.

### Fixed
- Live rollback e2e instability caused by synthetic state seeding.

---

## [1.2.0] - 2026-06-02

### Added
- Webhook/client behavior improvements that make policy admission and reconciliation more resilient.

### Changed
- Webhook reconciliation now uses informers/client behavior tuned for more reliable event handling.
- GPU-related e2e and policy behavior was refined for stability and consistency.
- Chart/docs content was updated to reflect the current release flow and user-facing guidance.

### Fixed
- Webhook error handling paths that could surface avoidable failures.
- Miscellaneous release-blocking regressions from the beta cycle.

---

## [1.1.0] - 2026-05-26

### Added
- PodAffinityPolicy automation for supported workload types, including preferred node placement rules
- StrimziPodSet workload support for automating Strimzi-managed Kafka pods
- Prometheus scraping support for controller metrics with a chart-managed metrics service and optional ServiceMonitor
- Added experimental support for GPU sharing using the KAI scheduler

### Changed
- GPU proactive policies can use `gpuOverallOptimal` recommendations from KAI for overall GPU optimization
- Resize summaries now show when recommendations were clamped to configured resource bounds

---

## [1.0.0] - 2026-05-07

### Changed
- No customer-facing changes in this release.

---

## [0.4.0] - 2026-05-05

### Added
- Namespace-level pause controls using the `rightsizing.kubex.ai/pause-until` annotation so automation can be paused across an entire namespace without annotating each pod individually

## [0.3.0] - 2026-05-01

### Added
- Time-based automation scheduling with configurable windows including all-day support, overnight windows, and 24:00 explicit end time
- Policy snapshot uploads to Kubex gateway via automation-gateway with configurable intervals

### Changed
- VPA resizing now requires active VPA recommendation conditions before allowing resize plans to prevent premature operations

### Fixed
- Stale owner recommendation cleanup flow for missing automation strategies
- Overlapping exclusion window handling by jumping to the latest end time
- Startup policy rescan now triggers automatically after readiness opens

---

## [0.2.1] - 2026-04-01

### Added
- Configurable webhook probe pod settings via GlobalConfiguration including image selection
- ImagePullSecrets and securityContext support for enhanced security configuration
- GlobalConfiguration singleton enforcement via validating webhook to prevent multiple instances

### Fixed
- Case-insensitive HPA kind detection to match HPA targets regardless of casing
- Guaranteed QoS resize plan calculation to correctly normalize requests and limits

---

## [0.2.0] - 2026-03-01

### Added
- Guaranteed QoS support with `retainGuaranteedQOS` flag to enforce requests==limits constraint

### Fixed
- Webhook retry handling to properly manage too-many-requests scenarios
- Resize method preservation in retry scenarios to maintain consistency across retries
- Workload-to-policy namespace matching to ensure correct policy application

---

## [0.1.3] - 2026-02-01

### Added
- Per-container enablement bounds to set different resource floor and ceiling limits for individual containers within a pod

### Fixed
- Webhook validation for inherited automation strategy bounds to ensure proper constraint enforcement

---

## [0.1.2] - 2026-01-15

### Added
- Webhook validation for policy automation strategy references to ensure referential integrity
- Protection against deleting automation strategies that are actively referenced by policies

### Fixed
- ENABLE_WEBHOOKS flag parsing to correctly interpret as boolean value

---

## [0.1.1] - 2026-01-01

### Changed
- Rebranded from previous name to Kubex

### Fixed
- Workload-to-policy namespace matching to ensure policies are applied to correct workloads

---
