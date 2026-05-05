# Changelog

All notable changes to the Kubex Automation Engine Helm chart will be documented in this file.

**Note:** All versions 0.x.x are pre-release versions and may contain breaking changes between releases. Production stability is targeted for version 1.0.0 and later.

---

## [0.4.0] - 2026-05-05

### Added
- Namespace-level pause controls using the `rightsizing.kubex.ai/pause-until` annotation so automation can be paused across an entire namespace without annotating each pod individually

---

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
