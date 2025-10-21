# RBAC Permissions Guide

This guide explains the RBAC permissions required by the Kubex Automation Controller and provides security guidance.

# Quick Links

- [RBAC Permissions Guide](#rbac-permissions-guide)
- [Quick Links](#quick-links)
  - [Overview](#overview)
  - [Service Accounts](#service-accounts)
  - [Controller Permissions](#controller-permissions)
    - [Core Resource Access](#core-resource-access)
    - [Workload Management](#workload-management)
  - [Webhook Permissions](#webhook-permissions)
  - [Security Considerations](#security-considerations)
    - [Principle of Least Privilege](#principle-of-least-privilege)
    - [Cluster Scope Requirements](#cluster-scope-requirements)
    - [Audit Trail](#audit-trail)
  - [Validating RBAC Setup](#validating-rbac-setup)

---

## Overview

The Kubex Automation Controller requires specific RBAC permissions to function properly. The chart automatically creates the necessary service accounts, cluster roles, and bindings with minimal required permissions.

## Service Accounts

The deployment creates two service accounts:

1. **`kubex-automation-controller-sa`** - Used by the automation controller and gateway components
2. **`kubex-webhook-sa`** - Used by the webhook server component

## Controller Permissions

The automation controller requires **cluster-wide** permissions to monitor and manage workloads across all namespaces:

### Core Resource Access
- **Namespaces**: `get`, `list`, `watch` - Monitor namespace configuration and scope validation
- **Nodes**: `get`, `list`, `watch` - Check node capacity for resource validation  
- **LimitRanges**: `get`, `list`, `watch` - Validate resource changes against namespace limits
- **ResourceQuotas**: `get`, `list`, `watch` - Ensure optimizations respect quota constraints
- **Services**: `get`, `list`, `watch` - Service discovery and health checks

### Workload Management
- **Pods**: `get`, `list`, `watch`, `create`, `update`, `patch`, `delete` - Full pod lifecycle management
- **Pod Eviction**: `create` - Restart pods to apply resource changes
- **Deployments**: `get`, `list`, `watch` - Monitor deployment configurations
- **ReplicaSets**: `get`, `list`, `watch` - Track pod ownership and scaling
- **Jobs**: `get`, `list`, `watch` - Monitor batch workload configurations

## Webhook Permissions

The webhook server operates with **minimal permissions** and primarily receives admission requests from the Kubernetes API server. It does not require explicit RBAC permissions beyond basic service account authentication.

## Security Considerations

### Principle of Least Privilege
- Controller has read-only access to most resources
- Write permissions limited to pods and pod eviction only  
- Webhook has no additional RBAC permissions beyond authentication

### Cluster Scope Requirements
- ClusterRole is required because automation works across all namespaces
- Individual namespace scoping is controlled via policy configuration, not RBAC
- Controller needs global visibility to validate cross-namespace constraints

### Audit Trail
- All RBAC permissions are explicitly defined in the chart templates
- Service account usage is logged in Kubernetes audit logs
- Resource modifications are traceable through controller logs

## Validating RBAC Setup

After installation, verify the RBAC configuration:

```bash
# Check service accounts exist
kubectl get serviceaccounts -n kubex | grep kubex

# Verify cluster role is created
kubectl get clusterrole kubex-automation-controller-cluster-role

# Check cluster role binding
kubectl get clusterrolebinding kubex-automation-controller-clusterrolebinding

# Test controller permissions (should show allowed actions)
kubectl auth can-i --list --as=system:serviceaccount:kubex:kubex-automation-controller-sa

# Verify webhook has basic authentication
kubectl auth can-i get pods --as=system:serviceaccount:kubex:kubex-webhook-sa
```