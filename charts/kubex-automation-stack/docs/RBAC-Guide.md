# RBAC Permissions Guide

This guide explains the RBAC permissions specific to Kubex data collection components in the kubex-automation-stack chart.

## Overview

The chart includes standard Prometheus and kube-state-metrics components (with their typical RBAC requirements), plus Kubex-specific components that require additional permissions:

- **Kubex Data Collector** (container-optimization-data-forwarder) - collects and forwards metrics from Prometheus to Kubex
- **Ephemeral Storage Metrics Collector** - reads node and pod storage data
- **Beyla** - Detects container application runtimes (Java, Go, Python, Node.js, etc.) (requires privileged mode)
- **GPU Exporter** - collects GPU utilization metrics (requires GPU device access and privileged mode)
- **Node Labeler** (optional) - writes labels to nodes and reads OpenShift machine resources
- **Node Exporter** - collects hardware and OS metrics from nodes (requires host access)

## Component RBAC Summary

| Component | Service Account Name | RBAC Type | Key Permissions | Enabled by Default | Special Privileges |
|-----------|---------------------|-----------|-----------------|-------------------|-------------------|
| Kubex Data Collector | `kubex-stack-kubex-forwarder` | ClusterRole | API discovery, token/subject reviews, namespaces (get) | ✅ Yes | None |
| Ephemeral Storage | `k8s-ephemeral-storage-metrics` | ClusterRole | nodes, nodes/proxy, nodes/stats, pods (get/list/watch) | ✅ Yes | None |
| Beyla | `kubex-beyla` | ClusterRole | pods, services, nodes (get/list/watch), replicasets (list/watch) | ✅ Yes | privileged, hostPID |
| GPU Exporter | `gpu-process-exporter` | ClusterRole | pods (get/list/watch) | ✅ Yes | privileged, hostPID, host mounts, device access |
| Node Labeler | `kubex-node-labeler` | ClusterRole + Role | nodes (get/list/watch/patch/update), events, machines/machinesets (OpenShift) | ❌ No | None |
| Node Exporter | `kubex-prometheus-node-exporter` | ClusterRole | token/subject reviews (when kube-rbac-proxy enabled) | ✅ Yes | hostNetwork, hostPID, host mounts |
| Prometheus Server | `kubex-prometheus-server` | ClusterRole | nodes, services, endpoints, pods, configmaps, ingresses (get/list/watch) | ✅ Yes | None |
| Kube-State-Metrics | `kubex-kube-state-metrics` | ClusterRole | Various K8s resources based on collectors config | ✅ Yes | None |

## Kubex-Specific Component Permissions

### Kubex Data Collector (container-optimization-data-forwarder)

The data collector queries the Prometheus API for metrics and forwards them to Kubex for rightsizing analysis and recommendations.

**What it does:**
- Queries Prometheus HTTP API endpoints for time-series metrics data
- Enriches metrics with Kubernetes cluster metadata (cluster ID, namespace details)
- Forwards aggregated data to Kubex for analysis
- Exposes its own metrics endpoint secured with kube-rbac-proxy for access control

**Why these permissions:**

The data collector needs minimal permissions to operate securely. It requires API discovery to detect cluster capabilities, authentication/authorization APIs to secure its own metrics endpoint via kube-rbac-proxy, and namespace read access to enrich metrics with cluster context. The collector does not directly access Prometheus data - it queries Prometheus via its HTTP API using service-to-service communication.

**ClusterRole permissions:**
- **Non-resource URLs:**
  - `/api`, `/api/v1` - `get` verb (for Kubernetes API discovery and version detection)

- **Authentication/Authorization (for kube-rbac-proxy):**
  - tokenreviews (authentication.k8s.io) - `create` verb
  - subjectaccessreviews (authorization.k8s.io) - `create` verb
  - These allow kube-rbac-proxy to validate authentication tokens and check authorization for requests to the collector's metrics endpoint

- **Cluster metadata:**
  - namespaces - `get` verb (to read namespace information and enrich forwarded metrics with context)

**Note:** The collector does not need permissions to read from Prometheus itself - it accesses Prometheus via the in-cluster service URL using Prometheus's own access controls.

### Ephemeral Storage Metrics Collector

Collects ephemeral storage usage metrics for containers, which is critical for Kubex rightsizing recommendations. Enabled by default.

**ClusterRole permissions:**
- nodes - `get`, `list`, `watch` verbs
- nodes/proxy - `get`, `list`, `watch` verbs
- nodes/stats - `get`, `list`, `watch` verbs (to access kubelet stats API)
- pods - `get`, `list`, `watch` verbs

### Node Labeler (Optional Component)

Adds labels to nodes indicating their Kubex Node Group assignment. Disabled by default; enable via `node-labeler.enabled: true`.

**When to enable:**
- When nodes lack standard cloud provider node pool/group labels (e.g., `label_cloud_google_com_gke_nodepool`, `label_eks_amazonaws_com_nodegroup`, `label_agentpool`, etc.)
- When you need additional Kubex-specific grouping labels on nodes beyond what the cloud provider provides
- For enhanced node group visibility and management in OpenShift environments (leverages Machine API for machine/machineset metadata)

**ClusterRole permissions (for node management):**
- nodes - `get`, `list`, `watch`, `patch`, `update` verbs
- events - `create`, `patch` verbs

**ClusterRole permissions (for OpenShift integration):**
- machines (machine.openshift.io) - `get`, `list`, `watch` verbs
- machinesets (machine.openshift.io) - `get`, `list`, `watch` verbs

**Role permissions (namespace-scoped for leader election):**
- leases (coordination.k8s.io) - `get`, `list`, `watch`, `create`, `update`, `patch`, `delete` verbs
- events - `create`, `patch` verbs

### OpenShift Monitoring Integration

When deploying on OpenShift with `openshift.enabled: true`, the data collector service account is bound to the built-in `cluster-monitoring-view` ClusterRole, granting read access to OpenShift's user workload monitoring APIs.

### Node Exporter (prometheus-node-exporter)

Collects hardware and OS-level metrics from each node for Kubex rightsizing analysis.

**ClusterRole permissions (when kube-rbac-proxy is enabled):**
- tokenreviews (authentication.k8s.io) - `create` verb
- subjectaccessreviews (authorization.k8s.io) - `create` verb

**Special privileges:**
- `hostNetwork: true` - access to host network namespace
- `hostPID: true` - access to host PID namespace
- Host path mounts: `/proc`, `/sys`, `/` (all read-only) - for system metrics

### Beyla (Container Runtime Detection)

Detects container application runtimes using eBPF instrumentation. Enabled by default.

**Purpose:**
- Identifies application runtimes running in containers (Java, Go, Python, Node.js, Ruby, .NET, etc.)
- Provides runtime visibility for Kubex workload analysis and recommendations

**ClusterRole permissions:**
- **Core resources:**
  - pods - `get`, `list`, `watch` verbs
  - services - `get`, `list`, `watch` verbs
  - nodes - `get`, `list`, `watch` verbs
- **Application resources:**
  - replicasets (apps) - `list`, `watch` verbs

**Service Account:** `kubex-beyla` (created when `beyla.serviceAccount.create: true`)

**Special privileges:**
- `hostPID: true` - access to host PID namespace for process instrumentation
- `privileged: true` - required for eBPF program loading and kernel instrumentation
- Context propagation capability (`NET_ADMIN`) available but disabled by default in this stack

### GPU Exporter (gpu-process-exporter)

Collects GPU utilization metrics for GPU-enabled workloads. Enabled by default.

**Purpose:**
- Addresses limitations of DCGM Exporter by providing container-level GPU metrics
- Required for Kubex GPU workload rightsizing recommendations
- Supports GPU sharing scenarios (time-slicing, MPS, KAI scheduler)

**Deployment behavior:**
- Runs only on nodes labeled with `nvidia.com/gpu.present=true` (typically set by the Nvidia GPU Operator)
- Safe to enable in clusters without GPUs - DaemonSet pods will not be scheduled on non-GPU nodes

**ClusterRole permissions:**
- pods - `get`, `list`, `watch` verbs

**Special privileges:**
- `hostPID: true` - access to host PID namespace
- `privileged: true` - runs as root with privileged container
- Host path mounts: `/` and `/proc` (both read-only) - for NVML libraries and process information
- Access to GPU device files on host (`/dev/nvidia*`)

## Standard Prometheus/KSM Components

The chart bundles standard Prometheus components with their typical RBAC requirements.

### Prometheus Server

Scrapes metrics from Kubernetes resources and other exporters.

**ClusterRole permissions:**
- **Core resources (for service discovery):**
  - nodes, nodes/metrics - `get`, `list`, `watch` verbs
  - services - `get`, `list`, `watch` verbs
  - endpoints - `get`, `list`, `watch` verbs
  - pods - `get`, `list`, `watch` verbs
  - configmaps - `get`, `list`, `watch` verbs
  - ingresses - `get`, `list`, `watch` verbs
- **Networking resources:**
  - ingresses, ingresses/status (networking.k8s.io) - `get`, `list`, `watch` verbs
  - endpointslices (discovery.k8s.io) - `get`, `list`, `watch` verbs
- **Non-resource URLs:**
  - `/metrics` - `get` verb (for scraping metrics endpoints)

**Service Account:** `kubex-prometheus-server`

### Kube-State-Metrics

Generates metrics about Kubernetes object state. Permissions are dynamically created based on enabled collectors.

**ClusterRole permissions (based on collectors in this stack):**
- cronjobs (batch) - `list`, `watch` verbs
- daemonsets (apps) - `list`, `watch` verbs
- deployments (apps) - `list`, `watch` verbs
- horizontalpodautoscalers (autoscaling) - `list`, `watch` verbs
- jobs (batch) - `list`, `watch` verbs
- namespaces - `list`, `watch` verbs
- nodes - `list`, `watch` verbs
- poddisruptionbudgets (policy) - `list`, `watch` verbs
- pods - `list`, `watch` verbs
- replicasets (apps) - `list`, `watch` verbs
- replicationcontrollers - `list`, `watch` verbs
- resourcequotas - `list`, `watch` verbs
- statefulsets (apps) - `list`, `watch` verbs

**Service Account:** `kubex-kube-state-metrics`

**Note:** The collectors list can be customized via `prometheus.kube-state-metrics.collectors` in values.yaml. Additional collectors will require corresponding RBAC permissions.

For detailed upstream documentation:
- [Prometheus RBAC](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus)
- [Kube-State-Metrics RBAC](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-state-metrics)

## Security Considerations

**Kubex-specific components:**
- Ephemeral storage collector requires read-only access to node stats endpoints and pods
- Data collector has minimal permissions (namespace read, API discovery)
- Node labeler is the only component with write access (node labels only) and is disabled by default

**Exporter components:**
- Node Exporter requires host access (`hostNetwork`, `hostPID`) but all mounts are read-only
- Beyla requires privileged mode and hostPID for runtime detection - enabled by default
- GPU exporter requires privileged mode, hostPID, and read-only filesystem access for container-level GPU metrics - enabled by default

**Standard components:**
- All Prometheus/KSM permissions are read-only except authentication/authorization checks
- Secret collection can be disabled via kube-state-metrics configuration if needed

## Validate RBAC

```bash
# List all service accounts created by the chart
kubectl get serviceaccount -n <namespace>

# List all RBAC resources (ClusterRoles, ClusterRoleBindings, etc.)
kubectl get clusterrole,clusterrolebinding | grep -E "(kubex|densify)"

# Check permissions for data collector service account
kubectl auth can-i --list --as=system:serviceaccount:<namespace>:kubex-stack-kubex-forwarder

# Check permissions for ephemeral storage metrics service account
kubectl auth can-i --list --as=system:serviceaccount:<namespace>:k8s-ephemeral-storage-metrics

# Check permissions for Beyla service account
kubectl auth can-i --list --as=system:serviceaccount:<namespace>:kubex-beyla

# Check permissions for GPU exporter service account
kubectl auth can-i --list --as=system:serviceaccount:<namespace>:gpu-process-exporter

# Check permissions for node labeler service account (if enabled)
kubectl auth can-i --list --as=system:serviceaccount:<namespace>:kubex-node-labeler

# Check permissions for node exporter service account
kubectl auth can-i --list --as=system:serviceaccount:<namespace>:kubex-prometheus-node-exporter

# Check permissions for Prometheus server service account
kubectl auth can-i --list --as=system:serviceaccount:<namespace>:kubex-prometheus-server

# Check permissions for kube-state-metrics service account
kubectl auth can-i --list --as=system:serviceaccount:<namespace>:kubex-kube-state-metrics
```

Replace `<namespace>` with your deployment namespace (default: `kubex`).

## Customization

You can customize Kubex-specific RBAC settings via values:

```yaml
# Data collector RBAC
container-optimization-data-forwarder:
  rbac:
    create: true  # Create RBAC resources

# Ephemeral storage metrics RBAC
k8s-ephemeral-storage-metrics:
  rbac:
    create: true  # Create RBAC resources
  serviceAccount:
    create: true
    name: k8s-ephemeral-storage-metrics

# Node labeler RBAC (optional component, disabled by default)
node-labeler:
  enabled: false  # Enable if you want nodes labeled with Kubex node groups
  rbac:
    create: true  # Create RBAC resources when enabled

# Node exporter RBAC (part of Prometheus chart)
prometheus:
  prometheus-node-exporter:
    rbac:
      create: true  # Create RBAC resources
    kubeRBACProxy:
      enabled: true  # Enable kube-rbac-proxy for authentication

# Ephemeral storage metrics RBAC (enabled by default)
k8s-ephemeral-storage-metrics:
  enabled: true  # Enabled by default for storage metrics
  rbac:
    create: true
  serviceAccount:
    create: true

# Beyla RBAC (enabled by default)
beyla:
  enabled: true  # Enabled by default for container runtime detection
  privileged: true  # Required for runtime detection
  rbac:
    create: true  # Create RBAC resources
  serviceAccount:
    create: true
    name: ""  # Defaults to kubex-beyla

# GPU exporter (enabled by default)
gpu-process-exporter:
  enabled: true  # Enabled by default for GPU workload monitoring
  rbac:
    create: true
  serviceAccount:
    create: true

# Prometheus and KSM RBAC
prometheus:
  rbac:
    create: true  # Create Prometheus server RBAC
  kube-state-metrics:
    rbac:
      create: true  # Create KSM RBAC
    collectors:  # Enabled collectors (determines required permissions)
      - cronjobs
      - daemonsets
      - deployments
      - horizontalpodautoscalers
      - jobs
      - namespaces
      - nodes
      - poddisruptionbudgets
      - pods
      - replicasets
      - replicationcontrollers
      - resourcequotas
      - statefulsets
  prometheus-node-exporter:
    rbac:
      create: true  # Create node exporter RBAC (for kube-rbac-proxy)

# OpenShift monitoring integration
openshift:
  enabled: false  # Set to true for OpenShift clusters
```

For the source-of-truth RBAC rules, inspect:
- Kubex components: `templates/` and `charts/*/templates/`
- Standard Prometheus/KSM: see upstream chart documentation

## Troubleshooting RBAC Issues

### Common Issues and Solutions

**1. Pods failing with "Forbidden" errors**
```bash
# Check pod logs for RBAC errors
kubectl logs -n <namespace> <pod-name>

# Verify service account exists
kubectl get sa -n <namespace>

# Check if ClusterRoleBinding exists
kubectl get clusterrolebinding | grep <component-name>
```

**2. Ephemeral storage metrics not collected**
- Ensure `k8s-ephemeral-storage-metrics.rbac.create: true`
- Verify access to kubelet stats API: `kubectl get --raw /api/v1/nodes/<node-name>/proxy/stats/summary`

**3. Beyla not detecting application runtimes**
- Verify privileged mode is enabled: `beyla.privileged: true`
- Check hostPID access in pod spec
- Review Beyla logs for permission errors

**4. Prometheus unable to scrape metrics**
- Verify Prometheus server service account has ClusterRole permissions
- Check NetworkPolicies that may block scraping
- Verify endpoints are discoverable: `kubectl get endpoints -n <namespace>`

**5. Node labeler not updating node labels** (when enabled)
- Ensure `node-labeler.rbac.create: true`
- Verify node `patch` and `update` permissions
- Check node-labeler logs for admission webhook denials

**6. OpenShift monitoring integration issues**
- Ensure `openshift.enabled: true`
- Verify `cluster-monitoring-view` ClusterRole exists in OpenShift
- Check if user workload monitoring is enabled in OpenShift cluster

### Security Best Practices

1. **Least Privilege**: Each component requests only the minimum permissions needed
2. **Read-Only by Default**: Most components have read-only access (except node-labeler)
3. **Namespace Isolation**: Use dedicated namespaces for monitoring components
4. **Service Account per Component**: Each sub-chart uses its own service account
5. **Audit RBAC Changes**: Review permissions before upgrading chart versions
6. **Monitor Privileged Pods**: Beyla and GPU exporter run privileged - ensure node security policies allow this

### Restricting Permissions

If your environment requires stricter RBAC:

```yaml
# Disable specific components
beyla:
  enabled: false  # Disable if privileged pods not allowed

gpu-process-exporter:
  enabled: false  # Disable if no GPU workloads or privileged pods not allowed

node-labeler:
  enabled: false  # Already disabled by default (requires write access to nodes)

# Use existing RBAC resources
container-optimization-data-forwarder:
  rbac:
    create: false  # Use pre-created RBAC
  serviceAccount:
    create: false
    name: existing-service-account
```
