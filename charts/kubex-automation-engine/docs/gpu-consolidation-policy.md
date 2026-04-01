# GPU Consolidation Policy

`GpuConsolidationPolicy` is a cluster-scoped controller that looks at scheduled pods carrying the `gpu-fraction` annotation and tries to consolidate them off an underutilized node.

## Behavior

- The controller scans all scheduled, non-terminal pods with `metadata.annotations["gpu-fraction"]`.
- Node GPU capacity is taken from `status.allocatable["nvidia.com/gpu"]`.
- Nodes with utilization below `spec.utilizationThresholdPercent` are candidates, but nodes with no GPU-fraction pods are ignored.
- Candidates are evaluated from most underutilized to least underutilized.
- A node is consolidated only when every GPU-fraction pod on that node can fit onto other non-empty GPU nodes without exceeding their allocatable capacity.
- The controller evicts all pods from the first drainable candidate node it finds in a reconcile loop.
- Reconciliation is policy-driven: the controller runs on `GpuConsolidationPolicy` changes and on the periodic timer from `spec.requeueAfter`.
- Pod and Node changes do not trigger immediate rescans.
- If no node can be fully drained, the controller records that outcome in status and waits for the next `spec.requeueAfter`.

## Spec

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: GpuConsolidationPolicy
metadata:
  name: gpu-consolidation
spec:
  utilizationThresholdPercent: 75
  requeueAfter: 1m
```

## Notes

- This policy is cluster-scoped only.
- It is self-contained and does not reference `AutomationStrategy`.
- Consolidation is based on GPU-fraction capacity only; it does not model CPU, memory, or scheduler affinity constraints.
- If you need faster reaction to workload churn, lower `spec.requeueAfter`.
