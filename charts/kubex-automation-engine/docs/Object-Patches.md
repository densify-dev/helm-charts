# Object Patches

Use object patches to apply one JSON Merge Patch and optional selector-aware JSON
Patch operations to any permitted object in the same scope. A patch may update
multiple fields: add a label or annotation, change a ConfigMap key, or remove
one field. Deleting an object patch does not roll back its target.

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
  retryAmount: 3
  requeueInterval: 5m
  drift:
    retryInterval: 5m
    retryAmount: 3
    stabilizationWindow: 15m
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
  requeueInterval: 5m
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

### Selector-aware operations

`jsonPatch` is optional and may be used alone or together with `patch`. When
both are present, the merge patch is applied first and selector operations are
applied afterward, in declaration order. Supported operations are `add`,
`remove`, and `replace`.

Each operation requires an RFC 6901 `path` containing exactly one `@` segment.
That segment selects elements from the array at the path prefix. The `selector`
is a CEL expression evaluated with the current element exposed as `item`.
`matchPolicy` defaults to `ExactlyOne`; use `All` to modify every matching
element. `add` and `replace` require a non-null `value`; `remove` must omit it.
Each patch supports at most 100 operations. Paths and selectors are limited to
1024 characters, and selectors that exceed the runtime CEL cost limit fail.

```yaml
spec:
  patch:
    metadata:
      labels:
        managed-by: kubex
  jsonPatch:
    - op: replace
      path: /spec/template/spec/containers/@/args
      selector: 'item.name == "app"'
      matchPolicy: ExactlyOne
      value:
        - --serve
    - op: add
      path: /spec/template/spec/containers/@/workingDir
      selector: 'item.name == "app"'
      value: /work
    - op: remove
      path: /spec/template/spec/containers/@/stdin
      selector: 'item.name == "app"'
```

`replace` supports the selected element itself or any existing descendant path.
`add` and `remove` are intentionally limited to one direct object member below
the selected element, such as `/containers/@/workingDir`. `add` creates or
replaces that member. `remove` ensures the member is absent; because `value` is
not used, omit it.
Array insertion, append, and selected-element removal are not supported because
they are not idempotent across reconciliation retries.

Unmatched array elements and their order are preserved. Selectors must remain
true after every operation and after later operations run. The complete plan
must replay without errors or further changes before the controller sends it.

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
`TargetNotFound`, and it is checked again after `requeueInterval`. If an applied
target disappears, status is `NeedsUpdate`, reason `TargetMissing`; when it
reappears, the patch is applied again. Deletion and recreation between checks is
not detected.

`requeueInterval` defaults to `5m` and must be positive. It controls ordinary
target observation, missing-target checks, duplicate-claim checks, and drift
stabilization observations. Reduce it for faster drift detection when the extra
API reads are acceptable.

After apply, the controller checks the target after each `requeueInterval`. Without
`spec.drift`, status becomes `NeedsUpdate`, reason `Drifted`, and `Drifted=True`,
but the controller does not repair the target until the reapply annotation is
set. This preserves report-only behavior for existing resources.

Set `spec.drift` to enable automatic repair. `retryInterval` defaults to `5m`,
must be positive, and cannot exceed 24 hours. `retryAmount` defaults to `3`;
`0` allows unlimited automatic repairs. `stabilizationWindow` defaults to
`15m` and must be positive.

When drift is found, the controller increments `status.driftRetryCount`, stores
the repair deadline in `status.nextDriftRetryTime`, and waits before reading the
target again. The delay doubles for each repair in the same streak and is capped
at 24 hours. For `retryInterval: 5m`, repairs wait 5 minutes, 10 minutes, then
20 minutes. If the target still differs at the deadline, the controller repairs
it. If another actor restored it, no patch request is sent.

After repair or external recovery, `nextDriftRetryTime` is cleared while
`driftRetryCount` is retained. The controller observes the target after each
`requeueInterval` through `stabilizationWindow`. With both defaults, three clean
five-minute observations occur before the counter resets. Drift during this
window continues the same exponential streak. Exhausting a finite drift retry
amount sets terminal `Error`, reason `DriftRetryLimitExceeded`, and
`Drifted=True`; polling stops until the spec changes or the reapply annotation
is set.

The relevant status fields are:

| Field | Meaning |
| --- | --- |
| `outcome` | `Success` when applied, `Failure` for drift or errors, and omitted while pending. |
| `reason` | Human-readable detail for the current outcome. |
| `observedGeneration` | Latest ObjectPatch generation processed by the controller. |
| `retryCount` | Transient patch-request retries in the current apply cycle. |
| `driftRetryCount` | Automatic drift repairs consumed in the current drift streak. |
| `nextDriftRetryTime` | Persisted deadline for the next target read and possible repair. Omitted during stabilization and ordinary observation. |
| `lastAttemptTime` | Most recent patch attempt. |
| `lastAppliedTime` | Most recent successful target patch. |

The common status fields follow the patch state. `Pending` leaves `status.outcome` empty and keeps the proposal `IN_PROGRESS`; `Applied` sets `outcome: Success`; `NeedsUpdate` and `Error` set `outcome: Failure`. `status.reason` contains the current detail and `status.observedGeneration` identifies the generation that produced it. A proposal becomes `APPLIED` or `FAILED` only when that generation matches `metadata.generation`.

Transient API errors during patch requests consume retry budget; target-read
errors do not. `retryAmount` defaults to `3` and means retries after the first
attempt: four total attempts by default. `retryAmount: 0` retries indefinitely.
This budget is independent of `drift.retryAmount`. Retrying is `Pending`, reason
`Retrying`; finite exhaustion is `Error`, reason `RetryLimitExceeded`, and
polling stops.

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

Patch resources may share a target when their static claims do not conflict. Claims
are arbitrated oldest first by creation timestamp, then name. A claimant blocked by
an accepted claimant does not reserve its other claims. `ObjectPatch` claims are
compared within their namespace; `ClusterObjectPatch` claims cluster-wide. A loser
reports `Error`, reason `TargetAlreadyClaimed`, and rechecks ownership after
`requeueInterval`.

Merge-patch claims recurse to leaf paths. Scalars, `null`, arrays, and empty
objects claim their exact path; arrays are atomic. Parent and child paths conflict.
For selector operations, `item.key == "literal"` and its reversed form claim the
entire selected array item, so different keys can coexist and the same key conflicts
even when child fields differ. Any other selector claims the entire array at the
path before `@`.

For example, two `ClusterObjectPatch` resources targeting the same Karpenter
`NodePool` can select `item.key == "node.kubernetes.io/instance-type"` and
`item.key == "karpenter.sh/capacity-type"` to update different requirement
items without conflicting.

## Troubleshooting

| Reason | Meaning and action |
| --- | --- |
| `SelfTargetNotAllowed` | Patch targets itself. `targetRef` is immutable; delete and recreate the patch with another target. |
| `UnsupportedTarget` | Scope mismatch, or unknown/invalid API version or kind. If `targetRef` is wrong, delete and recreate the patch with the correct target. If the API was temporarily unavailable and is now restored or installed, set the reapply annotation. |
| `InvalidPatch` | Inspect the condition. Ensure `patch` is a non-empty JSON object and `patch.metadata` is an object when present. |
| `PreflightRejected` | API server rejected the patch during dry-run validation. After correcting the patch or external target/admission issue, edit the patch or set the reapply annotation to start another cycle. |
| `LivePatchRejected` | API server rejected the live patch. After correcting the patch or external target/admission issue, edit the patch or set the reapply annotation to start another cycle. |
| `PatchNotApplied` | API server accepted the request but did not retain the requested result. After correcting the patch or external target/admission issue, edit the patch or set the reapply annotation to start another cycle. |
