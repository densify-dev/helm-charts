# RBAC Guide

This guide explains the RBAC model used by `kubex-automation-stack` for the stack-managed connector, CDI, and the supporting collection components.

## Overview

When `kubex-connector.enabled=true` and `kubex-ai-cdi.enabled=true`, the stack deploys:

- the in-cluster connector used for tunnel-based access
- the in-cluster CDI service used to expose cluster data
- stack-managed CDI RBAC resources

The stack keeps CDI RBAC ownership at the umbrella chart layer and disables subchart RBAC with `kubex-ai-cdi.rbac.enabled=false`.

## Component RBAC Summary

| Component | Service Account Name | RBAC Type | Key Permissions | Enabled by Default | Special Privileges |
|-----------|----------------------|-----------|-----------------|-------------------|-------------------|
| Kubex Data Collector | `kubex-stack-kubex-forwarder` | ClusterRole | API discovery, token/subject reviews, namespaces (get) | ✅ Yes | None |
| Connector | stack-owned | None | Uses runtime identity from the forwarder ConfigMap and `densify-api-secret` | ✅ Yes when enabled | None |
| CDI | `kubex-ai-cdi-sa` | ClusterRole + ClusterRoleBinding | core resources, workloads, logs, rollout APIs, Kubex CRDs, self-subject reviews | ✅ Yes when enabled | None |
| Ephemeral Storage | `k8s-ephemeral-storage-metrics` | ClusterRole | nodes, nodes/proxy, nodes/stats, pods (get/list/watch) | ✅ Yes | None |
| Beyla | `kubex-beyla` | ClusterRole | pods, services, nodes (get/list/watch), replicasets (list/watch) | ✅ Yes | privileged, hostPID |
| GPU Exporter | `gpu-process-exporter` | ClusterRole | pods (get/list/watch) | ✅ Yes | privileged, hostPID, host mounts, device access |
| Node Labeler | `kubex-node-labeler` | ClusterRole + Role | nodes, events, machines, machinesets, leases | ❌ No | None |
| Node Exporter | `kubex-prometheus-node-exporter` | ClusterRole | token/subject reviews (when kube-rbac-proxy enabled) | ✅ Yes | hostNetwork, hostPID, host mounts |
| Prometheus Server | `kubex-prometheus-server` | ClusterRole | nodes, services, endpoints, pods, configmaps, ingresses, endpointslices | ✅ Yes | None |
| Kube-State-Metrics | `kubex-kube-state-metrics` | ClusterRole | various K8s resources based on collectors config | ✅ Yes | None |

## Kubex Data Collector

The data collector queries Prometheus and forwards metrics to Kubex for rightsizing analysis.

It requires:

- API discovery
- token/subject review APIs for kube-rbac-proxy
- namespace read access for cluster context

## Connector

The connector does not create extra RBAC in the stack. It consumes:

- `kubex_host`
- `kubex_tenant_id`
- `kubex_cluster_name`
- `densify-api-secret`

The stack-managed connector runtime wiring is derived from the forwarder ConfigMap.

## CDI

The stack renders CDI RBAC itself and disables subchart RBAC with `kubex-ai-cdi.rbac.enabled=false`.

The stack-managed CDI resources are:

- `ServiceAccount/kubex-ai-cdi-sa`
- `ClusterRole/kubex-ai-cdi-reader`
- `ClusterRoleBinding/kubex-ai-cdi-reader`

## OpenShift Note

For OpenShift installs, use `values-openshift.yaml` so the stack-managed connector and CDI receive compatible security context defaults.

## Validation

Useful checks after install:

```bash
kubectl -n kubex get serviceaccount kubex-ai-cdi-sa
kubectl get clusterrole kubex-ai-cdi-reader
kubectl get clusterrolebinding kubex-ai-cdi-reader
kubectl auth can-i --list --as=system:serviceaccount:kubex:kubex-ai-cdi-sa
kubectl -n kubex get configmap kubex-kubex-stack -o yaml
```
