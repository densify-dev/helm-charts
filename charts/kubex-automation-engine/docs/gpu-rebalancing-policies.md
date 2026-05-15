# GPU Rebalancing Policies

> Experimental: GPU/KAI fields and related custom resources are subject to breaking changes. Set `spec.experimental.gpuKaiContract: v1alpha1-2026-04`.

`GpuRebalancingPolicy` and `ClusterWideGpuRebalancingPolicy` emit GPU rebalancing recommendations (upsize and downsize) from Prometheus utilization.

## Behavior

- Baseline is the live GPU allocation before first upsize and is persisted per container.
- Pod metrics are considered only after the pod age reaches `spec.minPodMetricsAge` (default `15m`).
- The policy evaluates two required GPU signals: `spec.metrics.compute` and `spec.metrics.memory`.
- Each metric is evaluated from per-pod aggregate GPU usage: the controller sums inferred GPU usage across all GPU containers in the pod, and compares that pod total against the summed current GPU allocation for those same containers.
- Upsize evaluation is pod-level per metric: if any eligible pod total exceeds that metric's threshold, that metric can request an upsize.
- Scale-back evaluation is owner-wide per metric: all eligible pod totals must stay below `currentAllocation * (spec.metrics.<signal>.scaleBack.thresholdPercent/100)` over `spec.metrics.<signal>.scaleBack.metricsWindow`, and every included container in those pods must have samples.
- `spec.metrics.<signal>.upsize.metricsWindow` and `spec.metrics.<signal>.scaleBack.metricsWindow` must be at least `1m`.
- Pods without `status.startTime` are treated as ineligible for metric checks.
- Containers missing a current GPU allocation are excluded from aggregate math and omitted from the emitted recommendation for that reconcile.
- Recommendations are emitted as GPU **requests** (`gpu`) and consumed by normal policy evaluation.
- Upsize target is the hottest eligible pod total plus `spec.metrics.<signal>.upsize.headroomPercent` (default `20`), capped by `spec.metrics.<signal>.upsize.maxPercent` relative to the included containers' summed baseline.
- Scale-back target is the hottest eligible pod total plus `spec.metrics.<signal>.scaleBack.headroomPercent` (default `20`), floored to the included containers' summed baseline.
- The controller compares the compute and memory recommendations and keeps the higher desired total.
- A lower recommendation is accepted when the existing recommendation was driven by the same metric.
- A lower cross-metric recommendation is accepted only if the previously driving metric also emits in that reconcile and its candidate is at or below the accepted lower total. Equal lower totals keep the existing driving metric to avoid ownership churn.
- Existing recommendations that predate driving-metric metadata do not lower until a non-decreasing recommendation establishes an owner metric.
- After a workload total is chosen, it is redistributed back to the selected pod's containers in proportion to their current GPU allocations.
- If neither upsize nor scale-back produces an accepted recommendation and current allocation still differs from baseline, the controller reuses the previous recommendation when present; otherwise it emits nothing.
- Workloads matched by GPU rebalancing policies are reevaluated periodically using `GlobalConfiguration.spec.gpuRebalancingCheckInterval` (default `1m`).

## Namespaced Spec

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: GpuRebalancingPolicy
metadata:
  name: gpu-rebalance
  namespace: default
spec:
  experimental:
    gpuKaiContract: v1alpha1-2026-04
  scope:
    labelSelector:
      matchLabels:
        app: my-gpu-app
  minPodMetricsAge: 15m
  metrics:
    compute:
      upsize:
        thresholdPercent: 125
        metricsWindow: 10m
        headroomPercent: 20
        maxPercent: 200
      scaleBack:
        thresholdPercent: 60
        metricsWindow: 10m
        headroomPercent: 20
      prometheus:
        metric: kubex_gpu_container_compute_utilization_percent
        namespaceLabel: namespace
        podLabel: pod
        containerLabel: container
    memory:
      upsize:
        thresholdPercent: 125
        metricsWindow: 10m
        headroomPercent: 20
        maxPercent: 200
      scaleBack:
        thresholdPercent: 60
        metricsWindow: 10m
        headroomPercent: 20
      prometheus:
        metric: kubex_gpu_container_memory_utilization_percent
        namespaceLabel: namespace
        podLabel: pod
        containerLabel: container
  automationStrategyRef:
    name: sample-automation-strategy
```

## Cluster-Wide Spec

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterWideGpuRebalancingPolicy
metadata:
  name: gpu-rebalance-cluster
spec:
  experimental:
    gpuKaiContract: v1alpha1-2026-04
  scope:
    namespaceSelector:
      operator: In
      values: ["*"]
    labelSelector:
      matchLabels:
        app: my-gpu-app
  minPodMetricsAge: 15m
  metrics:
    compute:
      upsize:
        thresholdPercent: 125
        metricsWindow: 10m
        headroomPercent: 20
        maxPercent: 200
      scaleBack:
        thresholdPercent: 60
        metricsWindow: 10m
        headroomPercent: 20
      prometheus:
        metric: kubex_gpu_container_compute_utilization_percent
        namespaceLabel: namespace
        podLabel: pod
        containerLabel: container
    memory:
      upsize:
        thresholdPercent: 125
        metricsWindow: 10m
        headroomPercent: 20
        maxPercent: 200
      scaleBack:
        thresholdPercent: 60
        metricsWindow: 10m
        headroomPercent: 20
      prometheus:
        metric: kubex_gpu_container_memory_utilization_percent
        namespaceLabel: namespace
        podLabel: pod
        containerLabel: container
  automationStrategyRef:
    name: sample-clusterwide-automation-strategy
```

## Global Prometheus Settings

Configure controller-wide Prometheus endpoint/timeouts via `GlobalConfiguration`:

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: GlobalConfiguration
metadata:
  name: global-config
spec:
  prometheus:
    url: http://prometheus.monitoring.svc:9090
    requestTimeout: 30s
```
