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

## Optional object patch permissions

The Helm chart enables four independent target grants by default:

```yaml
rbac:
  create: true
  objectPatches:
    nodePools: true
    horizontalPodAutoscalers: true
    podDisruptionBudgets: true
    clusterAutoscalers: true
```

When upgrading an older release with `helm upgrade --reuse-values`, a missing
`rbac.objectPatches` map or missing flags enable the corresponding grants.
Explicit `false` values remain disabled, and `rbac.create: false` disables
controller and optional object-patch RBAC.

Each enabled flag creates a separate ClusterRole and ClusterRoleBinding for the
controller service account, granting only `get` and `patch` on its resource:

| Flag under `rbac.objectPatches` | API group / resource |
| --- | --- |
| `nodePools` | `karpenter.sh/nodepools` |
| `horizontalPodAutoscalers` | `autoscaling/horizontalpodautoscalers` |
| `podDisruptionBudgets` | `policy/poddisruptionbudgets` |
| `clusterAutoscalers` | `autoscaling.openshift.io/clusterautoscalers` |

For example, disable NodePool and OpenShift ClusterAutoscaler access while keeping
the default HPA and PDB patch grants:

```yaml
rbac:
  objectPatches:
    nodePools: false
    clusterAutoscalers: false
```

Set any flag to `false` to omit its optional role and binding. HPA reads used by
safety checks remain in the main controller role even when
`horizontalPodAutoscalers: false`. NodePool access is not part of the main role.
`rbac.create: false` suppresses controller RBAC and these optional object-patch
roles and bindings. Compaction RBAC is controlled independently by
`compactionScheduler.enabled` and `compactionDescheduler.enabled`.

These flags do not revoke permissions granted by external roles. Non-Helm
deployments must supply target `get` and `patch` permissions separately.
Forbidden or Unauthorized target access sets `Error`, `Ready=False`, with reason
`TargetAccessDenied`. After restoring access, change the patch's `spec` or use the
[reapply annotation](Object-Patches.md#reapply-a-patch) to start a new apply cycle.

See [Object Patches](Object-Patches.md) for namespaced HPA/PDB and cluster-scoped
OpenShift ClusterAutoscaler examples.

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
