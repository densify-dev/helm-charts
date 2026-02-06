# kubex-ephemeral-storage-metrics

Helm chart for collecting ephemeral storage metrics from Kubernetes containers using the CRI-O container runtime.

## Overview

This chart deploys a DaemonSet that collects ephemeral storage metrics which are not available through standard Kubernetes metrics APIs. It integrates with Prometheus Operator via ServiceMonitor for metrics collection.

## Prerequisites

- Kubernetes cluster with CRI-O runtime (OpenShift default)
- Prometheus Operator (for ServiceMonitor support)
- User workload monitoring enabled (for OpenShift)

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `enabled` | Enable the exporter | `true` |
| `nameOverride` | Override the chart name | `""` |
| `fullnameOverride` | Override the full name | `""` |
| `image.repository` | Container image repository | `quay.io/prometheus/busybox` |
| `image.tag` | Container image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `tolerations` | Pod tolerations | `[]` |
| `podSecurityContext` | Pod security context | `{}` |
| `securityContext.allowPrivilegeEscalation` | Allow privilege escalation | `false` |
| `securityContext.capabilities.drop` | Dropped capabilities | `["ALL"]` |
| `securityContext.readOnlyRootFilesystem` | Use read-only root filesystem | `true` |
| `resources.limits.cpu` | CPU limit | `100m` |
| `resources.limits.memory` | Memory limit | `128Mi` |
| `resources.requests.cpu` | CPU request | `50m` |
| `resources.requests.memory` | Memory request | `64Mi` |
| `serviceMonitor.enabled` | Enable ServiceMonitor | `true` |
| `serviceMonitor.interval` | Scrape interval | `30s` |
| `serviceMonitor.scrapeTimeout` | Scrape timeout | `10s` |
| `serviceMonitor.labels` | Additional labels for ServiceMonitor | `{}` |
| `serviceMonitor.annotations` | Additional annotations for ServiceMonitor | `{}` |
| `nodeSelector` | Node selector | `{}` |
| `affinity` | Affinity rules | `{}` |

## License

Apache 2 Licensed. See LICENSE for full details.
