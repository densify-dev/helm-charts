# GitOps Integration Guide

This guide explains how to configure GitOps tools to work seamlessly with Kubex Automation Controller's resource mutations.

# Quick Links

- [GitOps Integration Guide](#gitops-integration-guide)
- [Quick Links](#quick-links)
- [Overview](#overview)
- [Argo CD Configuration](#argo-cd-configuration)
- [Flux Configuration](#flux-configuration)
- [OpenShift GitOps Configuration](#openshift-gitops-configuration)
- [Generic Annotation Strategy](#generic-annotation-strategy)
- [Verification](#verification)

---

## Overview

If your Kubernetes cluster uses GitOps tools and you are enabling automated mutations via the Kubex Mutating Admission Controller, you should configure your GitOps tool to ignore resource-related changes made by the controller.

This prevents:
- Applications from showing OutOfSync status unnecessarily
- Infinite reconciliation loops when the Self-Heal flag is enabled

## Argo CD Configuration

Update the argocd-cm ConfigMap to ignore differences in container resource requests and limits for common workload types:

```bash
kubectl patch configmap argocd-cm -n argocd --patch='
data:
  resource.customizations: |
    apps/Deployment:
      ignoreDifferences: |
        jqPathExpressions:
          - .spec.template.spec.containers[].resources.requests
          - .spec.template.spec.containers[].resources.limits
    apps/StatefulSet:
      ignoreDifferences: |
        jqPathExpressions:
          - .spec.template.spec.containers[].resources.requests
          - .spec.template.spec.containers[].resources.limits
    apps/DaemonSet:
      ignoreDifferences: |
        jqPathExpressions:
          - .spec.template.spec.containers[].resources.requests
          - .spec.template.spec.containers[].resources.limits
    argoproj.io/Rollout:
      ignoreDifferences: |
        jqPathExpressions:
          - .spec.template.spec.containers[].resources.requests
          - .spec.template.spec.containers[].resources.limits
'
```

## Flux Configuration

If you're using Flux v2, add these annotations to your workload manifests to prevent drift detection on resource changes:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: your-app
  annotations:
    # Prevent Flux from detecting resource changes as drift
    fluxcd.io/ignore: "false"
spec:
  template:
    metadata:
      annotations:
        # Ignore resource requests/limits changes
        config.kubernetes.io/local-config: "true"
```

## OpenShift GitOps Configuration

For OpenShift GitOps (based on Argo CD), use the same Argo CD configuration above:

```bash
kubectl patch configmap argocd-cm -n openshift-gitops --patch='
data:
  resource.customizations: |
    apps/Deployment:
      ignoreDifferences: |
        jqPathExpressions:
          - .spec.template.spec.containers[].resources.requests
          - .spec.template.spec.containers[].resources.limits
'
```

## Generic Annotation Strategy

For any GitOps tool, you can add these annotations to workloads that should ignore resource changes:

```yaml
metadata:
  annotations:
    kubex.automation/managed: "true"
    config.kubernetes.io/local-config: "true"
```

**Note**: For other GitOps tools not listed here, consult your tool's documentation for resource ignore patterns or contact your GitOps platform support for guidance on excluding resource specifications from drift detection.

## Verification

After configuring your GitOps tool:

1. **Deploy a test workload** that's included in your automation scope
2. **Wait for Kubex to optimize it** (check controller logs)
3. **Verify GitOps tool doesn't show drift** for the resource changes
4. **Test sync operations** to ensure they don't revert optimizations