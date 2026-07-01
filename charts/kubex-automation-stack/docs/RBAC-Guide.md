# RBAC Permissions Guide

This guide explains the RBAC permissions specific to Kubex data collection components in the kubex-automation-stack chart.

## Overview

The chart includes standard Prometheus and kube-state-metrics components (with their typical RBAC requirements), plus Kubex-specific components that require additional permissions:

- **Kubex Data Collector** (container-optimization-data-forwarder) - collects and forwards metrics from Prometheus to Kubex
- **Ephemeral Storage Metrics Collector** - reads node and pod storage data
- **Node Labeler** (optional) - writes labels to nodes and reads OpenShift machine resources

## Kubex-Specific Component Permissions

### Kubex Data Collector (container-optimization-data-forwarder)

The data collector collects metrics from Prometheus and forwards them to Kubex for analysis. It requires:

**ClusterRole permissions:**
- **Non-resource URLs:**
  - `/api`, `/api/v1` - `get` verb (for API discovery)

- **Authentication/Authorization (for secure communication):**
  - tokenreviews (authentication.k8s.io) - `create` verb
  - subjectaccessreviews (authorization.k8s.io) - `create` verb

- **Cluster metadata:**
  - namespaces - `get` verb (to read namespace information for context)

### Ephemeral Storage Metrics Collector

Collects ephemeral storage usage metrics for containers, which is critical for Kubex rightsizing recommendations.

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

## Standard Prometheus/KSM Components

The chart bundles standard Prometheus components with their typical RBAC requirements:

- **Prometheus Server** - read access to cluster resources for metric scraping
- **Kube-State-Metrics** - read access to Kubernetes object state
- **Node Exporter** - authentication/authorization for kube-rbac-proxy
- **Alertmanager, Pushgateway** - standard component permissions

These follow standard upstream RBAC patterns. See the subchart documentation for details:
- [Prometheus RBAC](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus)
- [Kube-State-Metrics RBAC](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-state-metrics)

## Security Considerations

**Kubex-specific components:**
- Ephemeral storage collector requires read-only access to node stats endpoints
- Data collector has minimal permissions (namespace read, API discovery)
- Node labeler is the only component with write access (node labels only) and is disabled by default

**Standard components:**
- All Prometheus/KSM permissions are read-only except authentication/authorization checks
- Secret collection can be disabled via kube-state-metrics configuration if needed

## Validate RBAC

```bash
# List all service accounts created by the chart
kubectl get serviceaccount -n kubex

# List all RBAC resources (ClusterRoles, ClusterRoleBindings, etc.)
kubectl get clusterrole,clusterrolebinding | grep kubex

# Check permissions for data collector service account
kubectl auth can-i --list --as=system:serviceaccount:kubex:kubex-container-optimization-data-forwarder

# Check permissions for ephemeral storage metrics service account
kubectl auth can-i --list --as=system:serviceaccount:kubex:k8s-ephemeral-storage-metrics

# Check permissions for node labeler service account (if enabled)
kubectl auth can-i --list --as=system:serviceaccount:kubex:kubex-node-labeler
```

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

# OpenShift monitoring integration
openshift:
  enabled: false  # Set to true for OpenShift clusters
```

For the source-of-truth RBAC rules, inspect:
- Kubex components: `templates/` and `charts/*/templates/`
- Standard Prometheus/KSM: see upstream chart documentation
