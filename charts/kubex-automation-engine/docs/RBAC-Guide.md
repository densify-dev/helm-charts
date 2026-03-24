# RBAC Permissions Guide

This guide explains the permission model for the current controller.

## Overview

The chart creates RBAC required for:

- reading cluster state used by safety checks and policy evaluation
- updating pods through resize or eviction flows
- reading and writing the controller's own CRDs and status

## Controller Permissions

The controller requires cluster-scoped read access to resources such as:

- namespaces
- nodes
- pods
- resource quotas
- limit ranges
- supported workload owners
- autoscaling resources used for conflict detection
- Kubex rightsizing CRDs

Write access is limited to the resources needed for automation execution and controller bookkeeping, including:

- pod eviction and pod resize paths
- events
- CR status and finalizers where needed

## Webhook Permissions

The webhook primarily serves admission requests. It relies on the deployed service account and the webhook registration objects created by the chart.

## Namespace-Scoped Pod Create Note

The controller's pod `create` permission used for dry-run webhook probing is namespace-scoped to the release namespace. Deploy the chart in the namespace you want used for webhook health probing, or keep custom manifests aligned with that behavior.

## Validate RBAC

```bash
kubectl get serviceaccount -n kubex
kubectl get clusterrole,role,clusterrolebinding,rolebinding | grep kubex
kubectl auth can-i --list --as=system:serviceaccount:kubex:<service-account-name>
```

For the source-of-truth RBAC rules, inspect the generated chart templates under `templates/`.
