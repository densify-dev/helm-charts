# GPU Reactive Policies

`GpuReactivePolicy` and `ClusterGpuReactivePolicy` emit GPU reactive recommendations (upsize and downsize) from Prometheus utilization.

## Behavior

- Baseline is the live GPU allocation before first upsize and is persisted per container.
- `spec.scope.containers` limits baseline state, metrics, aggregation, and redistribution to exact names. Empty means all regular containers and restartable init containers. Narrowing scope removes old recommendation and baseline entries for excluded containers.
- By default, only one same-kind GPU reactive policy contributes to a workload. With `globalConfiguration.multiPolicyContainerRightsizingEnabled: true`, separate container/resource targets can come from different policies, and `PolicyEvaluation` resolves overlaps. See [Multi-Policy Container Rightsizing](./Multi-Policy-Container-Rightsizing.md).
- Pod metrics are considered only after the pod age reaches `spec.minPodMetricsAge` (default `15m`).
- The policy evaluates two required GPU signals: `spec.metrics.compute` and `spec.metrics.memory`.
- Each metric declares its Prometheus value interpretation through `spec.metrics.<signal>.prometheus.interpretation`. `fullGPU` treats the value as a percentage of one whole GPU. `currentAllocation` treats it as a percentage of the container's current GPU allocation.
- Each metric is evaluated from per-pod aggregate GPU usage: the controller sums inferred GPU usage across all GPU containers in the pod, and compares that pod total against the summed current GPU allocation for those same containers.
- Upsize evaluation is pod-level per metric: if any eligible pod total exceeds that metric's threshold, that metric can request an upsize.
- Scale-back evaluation is owner-wide per metric: all eligible pod totals must stay below `currentAllocation * (spec.metrics.<signal>.scaleBack.thresholdPercent/100)` over `spec.metrics.<signal>.scaleBack.metricsWindow`, and every included container in those pods must have samples.
- `spec.metrics.<signal>.upsize.metricsWindow` and `spec.metrics.<signal>.scaleBack.metricsWindow` must be at least `1m`.
- Pods without `status.startTime` are treated as ineligible for metric checks.
- Containers missing a current GPU allocation are excluded from aggregate math and omitted from the emitted recommendation for that reconcile.
- Recommendations emit equal explicit `requests.gpu` and `limits.gpu` targets and are consumed by normal policy evaluation. Reactive policies do not enforce memory or generate burst capacity.
- With KAI NvFractions, baselines and capacity accounting use the request, not the burst limit. Selecting the equal reactive pair replaces an old burst allocation with a fixed allocation. Policy composition may select a separate static limit; the complete pair must satisfy `0 < request <= limit < 1`. Neither missing target falls back to live or template values.
- Upsize target is the hottest eligible pod total plus `spec.metrics.<signal>.upsize.headroomPercent` (default `20`), capped by `spec.metrics.<signal>.upsize.maxPercent` relative to the included containers' summed baseline.
- Scale-back target is the hottest eligible pod total plus `spec.metrics.<signal>.scaleBack.headroomPercent` (default `20`), floored to the included containers' summed baseline.
- The controller compares the compute and memory recommendations and keeps the higher desired total.
- A lower recommendation is accepted when the existing recommendation was driven by the same metric.
- A lower cross-metric recommendation is accepted only if the previously driving metric also emits in that reconcile and its candidate is at or below the accepted lower total. Equal lower totals keep the existing driving metric to avoid ownership churn.
- Existing recommendations that predate driving-metric metadata do not lower until a non-decreasing recommendation establishes an owner metric.
- After a workload total is chosen, it is redistributed back to the selected pod's containers in proportion to their current GPU allocations.
- If neither upsize nor scale-back produces an accepted recommendation and current allocation still differs from baseline, the controller reuses the previous recommendation when present; otherwise it emits nothing.
- Workloads matched by GPU reactive policies are reevaluated periodically using `GlobalConfiguration.spec.gpuReactiveCheckInterval` (default `1m`).

## NvFractions strategy requirements

The strategy must explicitly select `kai.gpuSharingMode: NvFractions` and `enablement.overrideScheduler: kai`; the API default remains `HamiCore`. Configure both `enablement.gpu.requests` and `enablement.gpu.limits` and set fractional ceilings below `1`, such as `"0.99999"`. Every changing member must allow its direction or neither GPU member changes. This includes enabling limit downsize when an equal reactive pair removes a previous burst limit. An unchanged member needs no direction enabled but must still be explicit. Use `inPlaceResize.enabled: false` and `podEviction.enabled: true` so changes reach runtime enforcement through replacement containers.

NvFractions examples are illustrative and non-executable pending release validation. KAI `vX.Y.Z` is an unresolved placeholder; compatibility with GPU Fractioning `0.1.9` has not been validated. See [GPU Sharing with KAI](./GPU-Sharing-with-KAI.md) for installation and static limit configuration. Limits allow opportunistic memory use above the guaranteed request; neither value guarantees GPU compute.

Metric normalization must match `prometheus.interpretation`. Use `currentAllocation` only when the metric denominator is the current request. Metrics normalized to the burst limit must be converted to a supported basis first; otherwise reactive sizing misinterprets utilization. Native NVIDIA and HAMi-core require equal selected logical targets. Configure these settings on strategy resources directly, not through legacy Helm `policy.policies`.

## Prometheus metric prerequisites

The `kubex_gpu_container_*` names in the examples below are placeholders for site-defined metrics, not metrics exported by GPU Fractioning or recording rules supplied by Kubex. Create and validate the required recording rules and attribution before applying these policies, or replace the names with equivalent metrics that meet this contract.

[GPU Fractioning v0.1.9 exports](https://github.com/kai-scheduler/gpu-fractioning/blob/v0.1.9/fractioning-manager/metricsd/README.md#gpu-metrics) these metrics by pod and GPU, with labels `namespace`, `pod`, `pod_uuid`, `gpu_uuid`, and `gpu`. There is no `container` label:

| Exported metric | Value |
| --- | --- |
| `gpu_fractioning_gpu_memory_used_bytes` | Used GPU memory in bytes, not a percentage. |
| `gpu_fractioning_gpu_sm_utilization_percent` | Raw SM utilization as a percentage of the physical GPU, capped at 100. |
| `gpu_fractioning_gpu_sm_utilization_percent_normalized` | Raw SM utilization divided by the memory **limit** fraction of physical GPU memory, falling back to request if no limit is present, capped at 100. |

Kubex queries each container by its configured namespace, pod, and container labels. Renaming an exported metric does not add container attribution or convert its units. The example metrics must meet these requirements:

- Attribute each pod/GPU series to the actual GPU container and expose its name as `container`. For the supported single-GPU-container, single-device NvFractions setup, verify that mapping from live pod metadata. Do not copy pod totals onto every container or attribute usage to the metricsd exporter container. Use `pod_uuid` and `gpu_uuid` to avoid joining stale pod incarnations or different devices.
- The example compute metric uses raw full-GPU SM percentage with `interpretation: fullGPU`. Do not substitute the normalized series with `currentAllocation` for a bursting pod. Its denominator is the limit, not Kubex's current request, and the cap loses information, so multiplying it by the limit/request ratio cannot reliably recover request-relative usage. Use the raw series instead.
- The example memory metric uses `100 * used_bytes / current_request_bytes` with `interpretation: currentAllocation`. Source the current request bytes for the same container and assigned GPU. Alternatively, use `100 * used_bytes / physical_total_bytes` for that device with `interpretation: fullGPU`. The exporter does not supply a memory percentage; do not use the burst limit or CUDA-visible total memory as a request denominator.

These are requirements, not ready-to-run recording rules. The metadata joins and denominator sources depend on your monitoring setup. Validate labels and values in Prometheus before enabling resizing; supplying an endpoint alone does not satisfy these prerequisites.

## Namespaced Spec

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: GpuReactivePolicy
metadata:
  name: gpu-reactive
  namespace: default
spec:
  scope:
    containers:
      - inference
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
        metric: kubex_gpu_container_sm_utilization_percent
        interpretation: fullGPU
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
        metric: kubex_gpu_container_memory_footprint_percent
        interpretation: currentAllocation
        namespaceLabel: namespace
        podLabel: pod
        containerLabel: container
  automationStrategyRef:
    name: sample-automation-strategy
```

## Cluster Spec

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterGpuReactivePolicy
metadata:
  name: gpu-reactive-cluster
spec:
  scope:
    containers:
      - inference
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
        metric: kubex_gpu_container_sm_utilization_percent
        interpretation: fullGPU
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
        metric: kubex_gpu_container_memory_footprint_percent
        interpretation: currentAllocation
        namespaceLabel: namespace
        podLabel: pod
        containerLabel: container
  automationStrategyRef:
    name: sample-cluster-automation-strategy
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
