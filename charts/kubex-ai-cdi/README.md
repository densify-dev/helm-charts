# Kubex AI CDI Helm Chart

This chart deploys the Kubex AI Cluster Data Interface (CDI), an in-cluster service that exposes Kubernetes cluster information over an HTTP API for consumption by Kubex components.

The CDI runs inside the target Kubernetes cluster and provides read access to cluster resources such as workloads, nodes, services, and policies through a standardized interface. It is typically deployed alongside the Kubex Connector.

It is intended to be installed through `kubex-automation-stack` and assumes stack-managed namespace, RBAC, and Kubex connection inputs.

Standalone installs keep RBAC enabled by default. The stack chart disables `rbac.enabled` and renders the ServiceAccount, ClusterRole, and ClusterRoleBinding itself.

## Prerequisites

- Kubernetes 1.24+
- Helm 3.x
- Appropriate RBAC permissions to create cluster-scoped resources

## Features

- Deploys the CDI service
- Creates the required ServiceAccount, ClusterRole, and ClusterRoleBinding for standalone installs
- Configurable logging, probes, and resource limits

## Configuration

- `service.name`
- `service.port`
- `worker.toolTimeout`
- `worker.maxPayloadBytes`
- `worker.enableClusterScopeOps`
- `worker.allowedNamespaces`
- `resources` (empty by default)
- `rbac.enabled`

## RBAC

The chart expects read access to common cluster resources needed for cluster data interface behavior, including:

- pods, services, configmaps, namespaces, nodes, events
- pod logs
- workload controllers such as deployments, daemonsets, statefulsets, replicasets
- rollout alternatives such as Argo Rollouts
- Kubex rightsizing CRDs
- self-subject access review APIs
