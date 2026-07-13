# Changelog

All notable changes to the Kubex Automation Engine Helm chart will be documented in this file.

## [1.6.1] - 2026-07-10

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
