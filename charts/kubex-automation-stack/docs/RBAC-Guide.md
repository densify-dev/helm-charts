# RBAC Guide

This guide explains the RBAC model used by `kubex-automation-stack` for the optional connector and CDI components.

## Overview

When `kubex-connector.enabled=true` and `kubex-ai-cdi.enabled=true`, the stack deploys:

- the in-cluster connector used for tunnel-based access
- the in-cluster CDI service used to expose cluster data
- stack-managed CDI RBAC resources

The stack keeps CDI RBAC ownership at the umbrella chart layer and disables subchart RBAC with `kubex-ai-cdi.rbac.enabled=false`.

## CDI RBAC Ownership

The stack renders these resources directly:

- `ServiceAccount/kubex-ai-cdi-sa`
- `ClusterRole/kubex-ai-cdi-reader`
- `ClusterRoleBinding/kubex-ai-cdi-reader`

Those resources are controlled through `rbac.permissions.cdi.*` in `values.yaml`.

## Default CDI Permissions

By default, the stack grants CDI read access to the cluster resources needed for cluster data interface behavior, including:

- core resources: `pods`, `services`, `configmaps`, `namespaces`, `nodes`, `events`
- pod logs: `pods/log`
- workloads: `deployments`, `daemonsets`, `statefulsets`, `replicasets`
- rollout APIs: `rollouts`, `analysisruns`, `experiments`
- Kubex rightsizing CRDs
- self-subject review APIs for capability discovery

The default rule set also includes optional integrations for:

- OpenShift Machine API resources when `openshift.enabled=true`
- Karpenter resources
- Karpenter AWS node class resources

## Connector RBAC

The connector itself does not create RBAC resources in the stack. It consumes runtime identity from the forwarder `ConfigMap` and credentials from `densify-api-secret` through `forwarderCredentialsSecretRef`.

The stack leaves `rbac.permissions.connector.*` disabled by default because the connector currently does not require additional Kubernetes API permissions for its tunnel role.

## Runtime Wiring

The stack-managed connector and CDI share cluster identity from the forwarder-generated `ConfigMap`:

- `kubex_host`
- `kubex_tenant_id`
- `kubex_cluster_name`

The connector uses those values to derive:

- `CONNECTOR_PROXY_WS_URL`
- `CONNECTOR_TENANT_ID`
- `CONNECTOR_CLUSTER_ID`
- `RELAY_UPSTREAM_WSS_URL`
- `DENSIFY_BASE_URL`

## Validation

Useful checks after install:

```bash
kubectl -n kubex get serviceaccount kubex-ai-cdi-sa
kubectl get clusterrole kubex-ai-cdi-reader
kubectl get clusterrolebinding kubex-ai-cdi-reader
kubectl auth can-i --list --as=system:serviceaccount:kubex:kubex-ai-cdi-sa
kubectl -n kubex get configmap kubex-kubex-stack -o yaml
```

## OpenShift Note

For OpenShift installs, use `values-openshift.yaml` so the stack-managed connector and CDI receive compatible security context defaults.
