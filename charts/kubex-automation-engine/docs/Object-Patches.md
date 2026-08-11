# Object Patches

Use object patches to apply one JSON Merge Patch to any permitted object in the
same scope. A patch may update multiple fields: add a label or annotation, change
a ConfigMap key, or remove one field. Deleting an object patch does not roll back
its target.

## Choose A Resource

- Use `ObjectPatch` for a namespaced target, in the same namespace.
- Use `ClusterObjectPatch` for a cluster-scoped target, such as a `Namespace`.
  `ClusterObjectPatch` itself is cluster-scoped.

`targetRef` has `apiVersion`, `kind`, and `name`, but no namespace. Therefore, an
`ObjectPatch` cannot target another namespace, and a `ClusterObjectPatch` cannot
target a namespaced object.

## Create A Patch

`targetRef` identifies an existing object. `patch` is a non-empty JSON Merge Patch.

```bash
kubectl create namespace patches-demo
kubectl create deployment application -n patches-demo --image=nginx
```

Namespaced target: label the existing Deployment with `managed-by=kubex`.

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ObjectPatch
metadata:
  name: deployment-patch
  namespace: patches-demo
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: application
  patch:
    metadata:
      labels:
        managed-by: kubex
```

Cluster-scoped target: add `managed-by=kubex` to the existing Namespace.

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterObjectPatch
metadata:
  name: namespace-patch
spec:
  targetRef:
    apiVersion: v1
    kind: Namespace
    name: patches-demo
  patch:
    metadata:
      labels:
        managed-by: kubex
```

```bash
kubectl apply -f deployment-patch.yaml
kubectl apply -f clusterobjectpatch.yaml
```

## Patch Semantics

JSON Merge Patch merges object members into the existing object. Nested object
members are merged, so adding a label preserves existing labels.

- `null` removes that field or map key.
- An array replaces the complete existing array; arrays are not merged item by
  item.

For a custom resource manifest containing literal `null` under `spec.patch`, use
`kubectl apply --server-side` to create it. `kubectl replace` is an option only
for updating an existing patch resource; it does not create one. Client-side
`kubectl apply` consumes `null` while constructing its own merge patch and may
not store the literal `null`.

## Lifecycle And Status

Creating a patch resource or editing its `spec` starts an apply cycle. Arbitrary
metadata edits do not. An already-matching target still succeeds and reports
`Applied`; success sets `Ready=True` and condition reason `Applied`. Successful
cycles reset retry count to `0`.

If the target is missing before first apply, status is `Pending`, reason
`TargetNotFound`, and it is checked again every five minutes. If an applied
target disappears, status is `NeedsUpdate`, reason `TargetMissing`; when it
reappears, the patch is applied again. Deletion and recreation between checks is
not detected.

After apply, five-minute checks report ordinary drift only: status becomes
`NeedsUpdate`, reason `Drifted`, and `Drifted=True`; the controller reports drift
but does not repair it until the reapply annotation is set. An externally
restored target can return to `Applied` naturally. `Ready=True` means the
requested patch is applied.

Transient API errors during patch requests consume retry budget; target-read
errors do not. `retryAmount` defaults to `3` and means retries after the first
attempt: four total attempts by default. `retryAmount: 0` allows one attempt.
Retrying is `Pending`, reason `Retrying`; exhaustion is `Error`, reason
`RetryLimitExceeded`, and polling stops.

```bash
kubectl get objectpatch deployment-patch -n patches-demo -o yaml
kubectl get clusterobjectpatch namespace-patch -o yaml
```

## Reapply A Patch

Set the reapply annotation to authorize one new apply cycle for drift, access
recovery, or `RetryLimitExceeded`:

```bash
kubectl annotate objectpatch deployment-patch -n patches-demo \
  automation.kubex.ai/apply-patch=true --overwrite

kubectl annotate clusterobjectpatch namespace-patch \
  automation.kubex.ai/apply-patch=true --overwrite
```

The controller clears the reapply annotation when it accepts the cycle. Do not
keep it in a GitOps manifest, or reconciliation may authorize repeated cycles.

## Permissions And Claims

The automation-controller service account needs `get` and `patch` on every
target API resource. Add RBAC only when the existing controller role does not
cover the target.

Forbidden or Unauthorized target access produces `Error`, `Ready=False`, and
reason `TargetAccessDenied`. Grant `get` and `patch`, then edit the patch or set
the reapply annotation.

Only one patch resource can claim a target. The oldest claimant wins; name
breaks a creation-time tie. `ObjectPatch` claims are compared within their
namespace; `ClusterObjectPatch` claims cluster-wide. A loser reports `Error`,
reason `TargetAlreadyClaimed`, and rechecks ownership every five minutes.

## Troubleshooting

| Reason | Meaning and action |
| --- | --- |
| `SelfTargetNotAllowed` | Patch targets itself. `targetRef` is immutable; delete and recreate the patch with another target. |
| `UnsupportedTarget` | Scope mismatch, or unknown/invalid API version or kind. If `targetRef` is wrong, delete and recreate the patch with the correct target. If the API was temporarily unavailable and is now restored or installed, set the reapply annotation. |
| `InvalidPatch` | Inspect the condition. Ensure `patch` is a non-empty JSON object and `patch.metadata` is an object when present. |
| `PreflightRejected` | API server rejected the patch during dry-run validation. After correcting the patch or external target/admission issue, edit the patch or set the reapply annotation to start another cycle. |
| `LivePatchRejected` | API server rejected the live patch. After correcting the patch or external target/admission issue, edit the patch or set the reapply annotation to start another cycle. |
| `PatchNotApplied` | API server accepted the request but did not retain the requested result. After correcting the patch or external target/admission issue, edit the patch or set the reapply annotation to start another cycle. |
