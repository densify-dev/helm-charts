# Changelog

All notable changes to the kubex-automation-stack chart will be documented in this file.


## [1.0.19] - 2026-07-14

### Added
- Added Linux OS requirement to nodeSelector for all stack components to ensure proper scheduling on Linux nodes
- Added configurable nodeSelector to gpu-process-exporter chart
- Added ephemeral storage metrics scaling configurations for all cluster size overlays (xsmall/small/medium/large)
  - Configured polling intervals, API rate limits, and concurrency settings scaled by cluster size
  - Added resource requests and limits for ephemeral storage metrics collector
  - Enabled garbage collection for medium and large clusters to handle pod churn
  - Extended probe timeouts for medium and large clusters to prevent false restarts during long polling cycles

### Changed
- Updated gpu-process-exporter dependency to v1.0.1
- Updated Prometheus chart dependency to v29.17.0
- Updated Beyla chart dependency to v1.16.10

## [1.0.18] - 2026-07-03

### Security
- Updated k8s-ephemeral-storage-metrics dependency to v1.21.0 to resolve CVE-2026-39821

### Changed
- Updated Prometheus chart dependency to v29.14.0

## [1.0.17] - 2026-06-23

### Changed
- Upgraded Prometheus chart dependency to v29.14.0 to overcome KSM sharding issues with v2.19.0

## [1.0.16] - 2026-06-11

### Added
- Added Grafana repository

## [1.0.15] - 2026-06-11

### Added
- Added Beyla as subchart
- Enabled ephemeral storage exporter by default

## [1.0.14] - 2026-06-04

### Added
- Added GPU recording rules for SM utilization metrics

## [1.0.13] - 2026-06-04

### Added
- Added support for native sidecar containers (init containers) in metrics collection
- Added Beyla to metrics scrape endpoints
- Updated ephemeral storage metrics regex

## [1.0.12] - 2026-05-20

### Fixed
- Fixed chart dependencies
- Fixed upgrade path
- Fixed README

## [1.0.11] - 2026-05-08

### Added
- Added gpu-process-exporter chart

### Changed
- Changed logos

## [1.0.10] - 2026-05-08

### Fixed
- Closed remaining metrics review items
- Simplified controller metrics relabeling

## [1.0.9] - 2026-05-07

### Added
- Added OCI artifacts support

### Fixed
- Fixed linting issues
- Aligned controller scrape with validated defaults
- Made controller scrape path explicit
- Enforced controller metrics port explicitly
- Tightened controller metrics scraping
- Scoped controller metrics scrape by service

### Documentation
- Clarified controller scrape contract
- Clarified controller metrics scrape behavior and intent

## [1.0.8] - 2026-04-17

### Added
- Allowed controller metrics scraping

### Fixed
- Restored shared scrape labels
- Deduplicated shared endpointslice relabels
- Pinned controller metrics scrape to HTTP
- Made controller metrics scrape explicit HTTP
- Dedicated controller metrics scrape
- Kept controller metrics samples
- Tightened controller metrics allowlist
- Dropped webhook from metrics allowlist

## [1.0.7] - 2026-04-16

### Changed
- Updated kubex-automation-stack dependencies
- Updated k8s-ephemeral-storage-metrics dependency to v1.20.1
- Updated helm lock with new chart version

## [1.0.6] - 2026-03-20

### Added
- Added OpenShift support to kubex-automation-stack
- Added OpenShift overlay install guidance

### Changed
- Updated container optimization data forwarder image
- Aligned kubex-automation-stack OpenShift values and docs

### Documentation
- Updated README to add steps on enabling workload monitoring in OpenShift

## [1.0.5] - 2026-03-19

### Added
- Created values-xsmall.yaml for small k8s clusters

### Changed
- Updated cluster size table in README
- Updated container range for small k8s clusters

## [1.0.4] - 2026-02-20

### Added
- Added ephemeral storage metrics to kubex-automation-stack
- Added Prometheus scrape job for k8s ephemeral storage metrics

### Changed
- Updated k8s-ephemeral-storage-metrics to v1.20.0
- Updated Prometheus relabeling to scrape k8s ephemeral storage metrics

### Fixed
- Resolved README merge markers and clarified subchart descriptions

## [1.0.3] - 2026-02-19

### Added
- Added node-labeler subchart (disabled by default)
- Added events permissions to clusterrole

### Changed
- Bumped kubex chart versions for automation stack

## [1.0.2] - 2026-01-29

### Changed
- Updated chart dependencies
- Updated chart versions

### Fixed
- Applied various fixes during rebranding

## [1.0.1] - 2025-11-27

### Changed
- Rebranded from Densify to Kubex across all chart components
- Updated branding assets and references

## [1.0.0] - 2025-11-05

### Added
- Improved Kubex Data Collector Helm support
- Values file consolidation
- Support for kubex-automation-controller chart installation

### Changed
- Overrode prometheus-node-exporter scheduling defaults

## [0.9.0] - 2025-01-09

### Changed
- Renamed to Kubex Collection Stack (from Densify Collection Stack)

---

## Component Dependencies

The kubex-automation-stack chart includes the following subcharts:

- **container-optimization-data-forwarder** (v4.x.x) - Data forwarding component
- **prometheus** (v29.x.x) - Metrics collection (conditional: `stack.prometheus.deploy`)
- **beyla** (v1.x.x) - Application observability (conditional: `beyla.enabled`)
- **k8s-ephemeral-storage-metrics** (v1.x.x) - Ephemeral storage metrics (conditional: `k8s-ephemeral-storage-metrics.enabled`)
- **gpu-process-exporter** (v1.x.x) - GPU metrics export (conditional: `gpu-process-exporter.enabled`)
- **node-labeler** (v0.x.x) - Node labeling automation (conditional: `node-labeler.enabled`)

## Support

For issues and questions, contact support@kubex.ai
