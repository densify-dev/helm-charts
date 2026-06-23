# GPU Sharing with KAI

This guide shows how to configure GPU sharing with KAI and Kubex Automation Engine.

Tested with KAI `v0.12.16`.

> [!IMPORTANT]
> GPU/KAI fields and related custom resources are experimental and subject to breaking changes. Set `spec.experimental.gpuKaiContract: v1alpha1-2026-04` on GPU/KAI resources.

## Prerequisites

- KAI is already installed in the cluster. [KAI installation instructions](https://github.com/kai-scheduler/KAI-Scheduler#installation-methods)
  - NOTE: Kubex has been tested with KAI version v0.12.16
- `kubex-crds`, `kubex-automation-engine` and `kubex-automation-stack` are already installed
  - When using `ClusterGpuRebalancingPolicy` or `GpuRebalancingPolicy`, Prometheus must be available for GPU metrics, typically via `kubex-automation-stack`.
  - If Prometheus runs at different endpoint, set `globalConfiguration.prometheus.url` to custom URL.

This guide works with either:

- a new KAI installation
- an existing KAI installation

For existing KAI-managed workloads, Kubex Automation Engine can update the `gpu-fraction` annotation without replacing the existing `kai.scheduler/queue` label.

### New KAI installation

Depending on your cloud provider and nvidia configuration, KAI's configuration must be adjusted. 

Here is an example of a minimal KAI installation tested with nvidia's GPU operator already running in the Kubernetes cluster. 

```
helm upgrade -i kai-scheduler oci://ghcr.io/kai-scheduler/kai-scheduler/kai-scheduler -n kai-scheduler --create-namespace \
  --version v0.12.16 \
  --set "global.gpuSharing=true" \
  --set "global.clusterAutoscaling=true" --set binder.additionalArgs[0]="--cdi-enabled=true"
```

### Prometheus notes

By default, the `kubex-automation-engine` chart configures GPU rebalancing policies to query Prometheus at `http://kubex-prometheus-server.kubex.svc`.

That matches the default Prometheus service name used by `kubex-automation-stack`.

If your Prometheus endpoint is different, override the controller-wide setting through the Helm value `globalConfiguration.prometheus.url`.

### Built-in KAI queues

If you want Kubex Automation Engine to create the built-in KAI queue resources used in this guide, enable them in your Helm values:

```yaml
kaiQueues:
  enabled: true
```

This creates the built-in Run:ai queue resources, including `kubex-unlimited-gpu-queue`.

## Starter Example

The following example creates:

- a `ClusterAutomationStrategy` for KAI-enabled workloads across the cluster
- a `ClusterProactivePolicy` that makes matching `Deployment` workloads managed by that strategy
- a `ClusterGpuRebalancingPolicy` that adjusts that shared GPU request based on Prometheus GPU metrics

Both policies target `Deployment` workloads in all namespaces that carry `nvidia.com/gpu.present: "true"`.

If you run KubeAI `kubeai.org/v1` `Model` objects instead of plain Deployments, `Model` is now part of default workload scope when policy `workloadTypes` is omitted. Target those CRs explicitly only when you want scope restricted to models:

```yaml
spec:
  scope:
    workloadTypes:
      - Model
```

In that mode, Kubex stores recommendations and rollback state on the `Model` owner, then propagates effects to model-owned pods.

```yaml
# Strategy shared by the baseline and rebalancing policies below.
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterAutomationStrategy
metadata:
  name: kai-gpu-sharing
spec:
  experimental:
    # Required contract version for the current experimental GPU/KAI integration.
    gpuKaiContract: v1alpha1-2026-04
  enablement:
    # Convert matching workloads to the KAI GPU-sharing flow.
    overrideScheduler: "kai"
    gpu:
      requests:
        # Allow lowering the requested GPU fraction when usage drops.
        downsize: true
        # Allow raising the requested GPU fraction when usage increases.
        upsize: true
        # Leave workloads that have no GPU request untouched.
        setFromUnspecified: false
  kai:
    vllm:
      # Keep vLLM below admitted gpu-fraction by 10%.
      # Example: 0.5 gpu-fraction -> 0.45 gpu-memory-utilization.
      gpuMemoryUtilizationBufferPercent: 10
  inPlaceResize:
    # Use restart/eviction flow instead of in-place pod resize.
    enabled: false
  podEviction:
    # Permit the controller to evict pods when it needs to apply a new size.
    enabled: true
---
# Baseline policy that makes matching workloads managed by the strategy.
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterProactivePolicy
metadata:
  name: kai-gpu-sharing-baseline
spec:
  scope:
    namespaceSelector:
      operator: In
      values:
        - "*"
    labelSelector:
      matchLabels:
        # Only target workloads that advertise an attached GPU.
        nvidia.com/gpu.present: "true"
    workloadTypes:
      # Limit the policy to Deployments across all namespaces.
      - Deployment
  automationStrategyRef:
    name: kai-gpu-sharing
---
# Policy that adjusts shared GPU fractions from Prometheus utilization data.
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterGpuRebalancingPolicy
metadata:
  name: kai-gpu-sharing-rebalancing
spec:
  experimental:
    # Required contract version for the current experimental GPU/KAI integration.
    gpuKaiContract: v1alpha1-2026-04
  scope:
    namespaceSelector:
      operator: In
      values:
        - "*"
    labelSelector:
      matchLabels:
        # Target the same GPU-enabled Deployments as the baseline policy.
        nvidia.com/gpu.present: "true"
    workloadTypes:
      - Deployment
  # Wait for each pod to build at least 10 minutes of metrics before evaluating it.
  minPodMetricsAge: 10m
  metrics:
    compute:
      upsize:
        # Increase the GPU fraction when compute usage reaches the current allocation.
        thresholdPercent: 100
        # Base the upsize decision on the most recent 2 minutes of samples.
        metricsWindow: 2m
        # Add 20% headroom above observed compute usage when increasing the request.
        headroomPercent: 20
        # Cap a single increase at 2x the current requested GPU fraction.
        maxPercent: 200
      scaleBack:
        # Reduce the GPU fraction only after compute usage stays below 75%.
        thresholdPercent: 75
        # Require 10 minutes of lower usage before scaling back.
        metricsWindow: 10m
        # Keep 20% spare compute capacity after scaling back.
        headroomPercent: 20
      prometheus:
        # Prometheus metric and label mapping used to join compute samples to containers.
        metric: kubex_gpu_container_sm_utilization_percent
        # Treat metric values as percentages of one full GPU.
        interpretation: fullGPU
        namespaceLabel: namespace
        podLabel: pod
        containerLabel: container
    memory:
      upsize:
        # Apply the same upsize behavior using GPU memory utilization signals.
        thresholdPercent: 100
        # Base the upsize decision on the most recent 2 minutes of samples.
        metricsWindow: 2m
        # Add 20% headroom above observed memory usage when increasing the request.
        headroomPercent: 20
        # Cap a single increase at 2x the current requested GPU fraction.
        maxPercent: 200
      scaleBack:
        # Reduce the GPU fraction only after memory usage stays below 75%.
        thresholdPercent: 75
        # Require 10 minutes of lower usage before scaling back.
        metricsWindow: 10m
        # Keep 20% spare memory capacity after scaling back.
        headroomPercent: 20
      prometheus:
        # Prometheus metric and label mapping used to join memory samples to containers.
        metric: kubex_gpu_container_memory_footprint_percent
        # Treat metric values as percentages of the container's current GPU allocation.
        # Example: if current KAI allocation is 0.30 and pod uses 15% of the whole GPU, the metric will show 50% usage
        interpretation: currentAllocation
        namespaceLabel: namespace
        podLabel: pod
        containerLabel: container
  automationStrategyRef:
    # Apply recommended changes through the strategy defined above.
    name: kai-gpu-sharing
```

## Automation Strategy Notes

GPU metric interpretation defaults to `fullGPU`, which means Prometheus values are treated as percentages of one whole GPU. Set `prometheus.interpretation: currentAllocation` when a metric reports utilization relative to the container's current GPU allocation, such as KAI GPU memory utilization.

For KAI-enabled workloads, start with `spec.inPlaceResize.enabled: false`.

- Eviction-based resize is the safer path today for KAI-enabled workloads.
- In-place resizing for KAI-enabled workloads can be experimented with, but it is currently unstable.

## vLLM tuning with KAI gpu-fraction

If workload starts vLLM server, you can ask AutomationStrategy admission mutation to tune `--gpu-memory-utilization` from admitted KAI `gpu-fraction`.

Example math:

- admitted `gpu-fraction`: `0.5`
- `spec.kai.vllm.gpuMemoryUtilizationBufferPercent`: `10`
- resulting vLLM arg: `--gpu-memory-utilization=0.45`

Behavior:

- requires experimental contract: `spec.experimental.gpuKaiContract: v1alpha1-2026-04`
- only runs for KAI GPU request admission mutation
- only mutates detected vLLM containers
- updates existing `--gpu-memory-utilization=<value>`
- updates existing split form `--gpu-memory-utilization <value>`
- appends flag if missing
- does not leave duplicate flag entries

## Existing KAI Installations

For workloads that are already scheduled through KAI, these policies will:

- keep the existing `kai.scheduler/queue` label on the workload template
- let Kubex Automation Engine update `gpu-fraction` as policies are applied

That allows Kubex Automation Engine to participate in GPU sharing without taking over queue assignment.

If you want Kubex to overwrite an existing `kai.scheduler/queue` label, set `spec.kai.setQueueWhenSpecified: true` in your AutomationStrategy.

For workloads that are not currently scheduled through KAI, these policies will:

- replace the `nvidia.com/gpu` resource allocation with KAI `gpu-fraction` annotations
- apply the KAI queue `kubex-unlimited-gpu-queue` (Kubex built-in KAI queue that doesn't perform quota allocations)

## KAI node consolidation

`GpuConsolidationPolicy` is cluster-scoped and works separately from `AutomationStrategy`. Use it to look for underutilized GPU nodes inside a single compatible node pool and evict pods from a node only when the controller believes all `gpu-fraction` pods on that node can fit elsewhere in the same pool.

Start with one narrowly scoped policy per compatibility pool:

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
      cloud.google.com/gke-accelerator: nvidia-tesla-t4
  utilizationThresholdPercent: 75
  requeueAfter: 1m
```

If you have multiple GPU compatibility pools, create multiple policies instead of one broad selector. For example, keep `nvidia-tesla-t4` nodes separate from `nvidia-l4` nodes or from a different provider-specific GPU node class.

### Node consolidation limitations

GPU node consolidation is very early and has known limitations.

- It assumes pods will be schedulable on other nodes if they fit by GPU fraction.
- It does not yet fully model all other scheduler constraints.
- That can lead to frequent evictions when the controller chooses a node that looks drainable from GPU capacity alone but cannot actually be rescheduled cleanly.
- It may behave unpredictably with nodes that have multiple GPUs.

Use it carefully and start with a narrowly scoped worker pool.
