# GPU Sharing with KAI

This guide shows how to configure GPU sharing with KAI and Kubex Automation Engine.

Tested with KAI `v0.12.16`.

> [!IMPORTANT]
> GPU/KAI fields and related custom resources are experimental and subject to breaking changes. Set `spec.experimental.gpuKaiContract: v1alpha1-2026-04` on GPU/KAI resources.

## Prerequisites

- KAI is already installed in the cluster
- `kubex-crds` and `kubex-automation-engine` are already installed
- Prometheus is available for GPU utilization metrics if you want to use `GpuRebalancingPolicy`

This guide works with either:

- a new KAI installation
- an existing KAI installation

For existing KAI-managed workloads, Kubex Automation Engine can update the `gpu-fraction` annotation without replacing the existing `kai.scheduler/queue` label.

## Starter Example

The following example creates:

- an `AutomationStrategy` for KAI-enabled workloads in namespace `ml-team-a`
- a `StaticPolicy` that sets an initial shared GPU request for matching `Deployment` workloads
- a `GpuRebalancingPolicy` that adjusts that shared GPU request based on Prometheus GPU metrics

Both policies target `Deployment` workloads in a specific namespace that carry `nvidia.com/gpu.present: "true"`.

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: AutomationStrategy
metadata:
  name: kai-gpu-sharing
  namespace: ml-team-a
spec:
  experimental:
    gpuKaiContract: v1alpha1-2026-04
  enablement:
    gpu:
      overrideScheduler: "kai"
      requests:
        downsize: true
        upsize: true
        setFromUnspecified: false
  kai:
    queue: kubex-unlimited-gpu-queue
    setQueueWhenSpecified: false
  inPlaceResize:
    enabled: false
  podEviction:
    enabled: true
---
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: StaticPolicy
metadata:
  name: kai-gpu-sharing-baseline
  namespace: ml-team-a
spec:
  scope:
    labelSelector:
      matchLabels:
        nvidia.com/gpu.present: "true"
    workloadTypes:
      - Deployment
  resources:
    containers:
      "*":
        requests:
          gpu: "0.25"
  automationStrategyRef:
    name: kai-gpu-sharing
---
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: GpuRebalancingPolicy
metadata:
  name: kai-gpu-sharing-rebalancing
  namespace: ml-team-a
spec:
  experimental:
    gpuKaiContract: v1alpha1-2026-04
  scope:
    labelSelector:
      matchLabels:
        nvidia.com/gpu.present: "true"
    workloadTypes:
      - Deployment
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
    name: kai-gpu-sharing
```

## Automation Strategy Notes

For KAI-enabled workloads, start with `spec.inPlaceResize.enabled: false`.

- Eviction-based resize is the safer path today for KAI-enabled workloads.
- In-place resizing for KAI-enabled workloads can be experimented with, but it is currently unstable.

## Existing KAI Installations

For workloads that are already scheduled through KAI:

- keep the existing `kai.scheduler/queue` label on the workload template
- let Kubex Automation Engine update `gpu-fraction` as policies are applied

That allows Kubex Automation Engine to participate in GPU sharing without taking over queue assignment.

If you want queue assignment to be done via Kubex, set `spec.kai.setQueueWhenSpecified: false` in your AutomationStrategy.

## GPU Node Consolidation

`GpuConsolidationPolicy` can be used to consolidate KAI GPU workloads onto fewer GPU nodes.

Example targeting a specific worker pool:

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: GpuConsolidationPolicy
metadata:
  name: kai-gpu-workers-a
spec:
  experimental:
    gpuKaiContract: v1alpha1-2026-04
  nodeSelector:
    matchLabels:
      nodepool: gpu-workers-a
  utilizationThresholdPercent: 70
  requeueAfter: 2m
```

## Consolidation Limitations

GPU node consolidation is very early and has known limitations.

- It assumes pods will be schedulable on other nodes if they fit by GPU fraction.
- It does not yet fully model all other scheduler constraints.
- That can lead to frequent evictions when the controller chooses a node that looks drainable from GPU capacity alone but cannot actually be rescheduled cleanly.
- It may behave unpredictably with nodes that have multiple GPUs.

Use it carefully and start with a narrowly scoped worker pool.
