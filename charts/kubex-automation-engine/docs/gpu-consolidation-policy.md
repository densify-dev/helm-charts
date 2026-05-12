# GPU Consolidation Policy

> Experimental: GPU/KAI fields and related custom resources are subject to breaking changes. Set `spec.experimental.gpuKaiContract: v1alpha1-2026-04`.

`GpuConsolidationPolicy` is a cluster-scoped controller that looks at scheduled pods carrying the `gpu-fraction` annotation and tries to consolidate them off an underutilized node.

## Behavior

- The controller scans all scheduled, non-terminal pods with `metadata.annotations["gpu-fraction"]`.
- `spec.nodeSelector` is required and uses standard Kubernetes label selector semantics.
- Each policy defines one compatibility pool. Create multiple policies when you need multiple compatible node pools.
- Only nodes selected by `spec.nodeSelector` are considered compatible for candidate selection and destination placement.
- Selected nodes are expected to be mutually compatible for GPU workload movement.
- Node GPU capacity is taken from `status.allocatable["nvidia.com/gpu"]`.
- Nodes with utilization below `spec.utilizationThresholdPercent` are candidates, but nodes with no GPU-fraction pods are ignored.
- Candidates are evaluated from most underutilized to least underutilized.
- A node is consolidated only when every GPU-fraction pod on that node can fit onto other non-empty GPU nodes without exceeding their allocatable capacity.
- The controller evicts all pods from the first drainable candidate node it finds in a reconcile loop.
- Eviction is node-wide for a selected consolidation candidate: once a node is marked for consolidation, every evictable pod on that node is targeted, including pods without workload owners such as static pods.
- Reconciliation is policy-driven: the controller runs on `GpuConsolidationPolicy` changes and on the periodic timer from `spec.requeueAfter`.
- Pod and Node changes do not trigger immediate rescans.
- If no node can be fully drained, the controller records that outcome in status and waits for the next `spec.requeueAfter`.

## Examples

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: GpuConsolidationPolicy
metadata:
  name: gpu-consolidation-pool-a
spec:
  experimental:
    gpuKaiContract: v1alpha1-2026-04
  nodeSelector:
    matchLabels:
      kubex.ai/gpu-pool: pool-a
  utilizationThresholdPercent: 75
  requeueAfter: 1m
```

Use one policy per compatibility pool:

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: GpuConsolidationPolicy
metadata:
  name: gpu-consolidation-l40s
spec:
  experimental:
    gpuKaiContract: v1alpha1-2026-04
  nodeSelector:
    matchExpressions:
    - key: kubex.ai/gpu-pool
      operator: In
      values:
      - batch-l40s
    - key: accelerator.nvidia.com/class
      operator: In
      values:
      - l40s
  utilizationThresholdPercent: 70
  requeueAfter: 2m
---
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: GpuConsolidationPolicy
metadata:
  name: gpu-consolidation-h100
spec:
  experimental:
    gpuKaiContract: v1alpha1-2026-04
  nodeSelector:
    matchLabels:
      kubex.ai/gpu-pool: training-h100
  utilizationThresholdPercent: 80
  requeueAfter: 1m
```

## Notes

- This policy is cluster-scoped only.
- `spec.nodeSelector` is the compatibility boundary for consolidation.
- It is self-contained and does not reference `AutomationStrategy`.
- Consolidation is based on GPU-fraction capacity only; it does not model CPU, memory, or scheduler affinity constraints.
- Consolidation drain behavior is not limited to GPU-fraction pods. After a node is selected, the node is drained by evicting all evictable pods on it, even when some of those pods do not have owners.
- If `spec.nodeSelector` matches no nodes, the policy reports `NoMatchingNodeSelector` and performs no evictions.
- If you need faster reaction to workload churn, lower `spec.requeueAfter`.
