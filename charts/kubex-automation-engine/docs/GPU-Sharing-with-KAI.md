# GPU Sharing with KAI

This guide shows how to configure GPU sharing with KAI and Kubex Automation Engine.

This guide was tested with KAI `v0.17.0` and HAMi-core `1.1.0-chart`.

> [!IMPORTANT]
> GPU/KAI fields and related custom resources are experimental and subject to breaking changes. Set `spec.experimental.gpuKaiContract: v1alpha1-2026-07` on GPU/KAI resources.

## Prerequisites

- KAI is already installed in the cluster. [KAI installation instructions](https://github.com/kai-scheduler/KAI-Scheduler#installation-methods)
  - Kubex has been tested with KAI version v0.17.0.
- `kubex-crds`, `kubex-automation-engine`, and `kubex-automation-stack` are already installed.
  - The `kubex-automation-engine` release must enable `webhook.podMutation.additionalWebhook.enabled` as shown below.
  - When using `ClusterGpuReactivePolicy` or `GpuReactivePolicy`, Prometheus must be available for GPU metrics, typically via `kubex-automation-stack`.
  - If Prometheus runs at a different endpoint, set `globalConfiguration.prometheus.url` to the custom URL.

This guide works with either of the following:

- A new KAI installation.
- An existing KAI installation.

For existing KAI-managed workloads, Kubex Automation Engine can update the `gpu-fraction` annotation without replacing the existing `kai.scheduler/queue` label.

### Required Kubex webhook values

KAI relies on resource information updated by Kubex when making admission decisions. Before deploying the KAI-managed workloads described in this guide, configure the `kubex-automation-engine` Helm release with the additional webhook enabled:

```yaml
webhook:
  podMutation:
    additionalWebhook:
      enabled: true
```

This setting is required for the KAI integration. The early Kubex invocation applies selected resources and KAI metadata such as `gpu-fraction`, the queue label, and the scheduler selection before KAI makes its decision. The late invocation restores Kubex-selected resources after other mutators run while keeping the metadata idempotent.

### New KAI installation

Depending on your cloud provider and NVIDIA configuration, you may need to adjust KAI's configuration.

The following example shows a minimal KAI installation tested with the NVIDIA GPU Operator already running in the Kubernetes cluster.

It also installs HAMi-core to enforce GPU memory limits for CUDA workloads. The `kai-resource-isolator` chart deploys HAMi-core's GPU library synchronization components on selected GPU nodes.

HAMi-core is optional but preferred: it enforces KAI fractions, while Kubex's [GPU Reactive Policies](./gpu-reactive-policies.md) can only increase fractions on a best-effort basis as pods approach their limits.

Create `kai-resource-isolator.values.yaml`:

```yaml
librarySync:
  nodeSelector:
    "nvidia.com/gpu.present": "true"
```

Create `kai-scheduler.values.yaml`:

```yaml
binder:
  additionalArgs:
    - --cdi-enabled=true
  plugins:
    hamicore:
      enabled: true
global:
  clusterAutoscaling: true
  gpuSharing: true
```

Install HAMi-core first:

```bash
helm upgrade --install kai-resource-isolator oci://docker.io/projecthami/kai-resource-isolator \
  --namespace kai-resource-isolator \
  --create-namespace \
  --version 1.1.0-chart \
  -f kai-resource-isolator.values.yaml
```

Then install the KAI scheduler:

```bash
helm upgrade --install kai-scheduler oci://ghcr.io/kai-scheduler/kai-scheduler/kai-scheduler \
  --namespace kai-scheduler \
  --create-namespace \
  --version v0.17.0 \
  -f kai-scheduler.values.yaml
```

### Verify HAMi-core

If HAMi-core is used, verify that GPU nodes run pods from the following DaemonSet:

```bash
kubectl -n kai-resource-isolator get daemonset kai-resource-isolator-libsync
```

The DaemonSet's `DESIRED`, `CURRENT`, and `READY` counts should cover all eligible GPU nodes. If HAMi-core is unavailable or you do not want to use it, use `GpuReactivePolicy` or `ClusterGpuReactivePolicy` to monitor GPU memory utilization through Prometheus and upsize workloads when utilization crosses configured thresholds. Reactive policies resize GPU allocations; they do not enforce memory limits. Prefer HAMi-core when possible so memory is enforced instead of upsizing pods to accommodate higher usage. See [GPU Reactive Policies](./gpu-reactive-policies.md).

### Prometheus notes

By default, the `kubex-automation-engine` chart configures GPU reactive policies to query Prometheus at `http://kubex-prometheus-server.kubex.svc`.

This matches the default Prometheus service name used by `kubex-automation-stack`.

If your Prometheus endpoint is different, override the controller-wide setting through the Helm value `globalConfiguration.prometheus.url`.

### Built-in KAI queues

If you want Kubex Automation Engine to create the built-in KAI queue resources used in this guide, enable them in your Helm values:

```yaml
kaiQueues:
  enabled: true
```

This creates the built-in Run:ai queue resources, including `kubex-unlimited-gpu-queue`.

## Starter Example

This example creates the following resources:

- A `ClusterAutomationStrategy` for KAI-enabled workloads across the cluster
- A `ClusterProactivePolicy` that makes matching `Deployment` workloads managed by that strategy
- A `ClusterGpuReactivePolicy` that adjusts the shared GPU request based on Prometheus GPU metrics

Both policies target `Deployment` workloads in all namespaces that carry `nvidia.com/gpu.present: "true"`.

```yaml
spec:
  scope:
    workloadTypes:
      - Model
```

In that mode, Kubex stores recommendations and rollback state on the `Model` owner, then propagates effects to model-owned pods.

```yaml
# Strategy shared by the baseline and reactive policies below.
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterAutomationStrategy
metadata:
  name: kai-gpu-sharing
spec:
  experimental:
    # Required contract version for the current experimental GPU/KAI integration.
    gpuKaiContract: v1alpha1-2026-07
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
      # Keep vLLM's GPU memory utilization 10% below the admitted gpu-fraction.
      # For example, 0.5 gpu-fraction produces 0.45 gpu-memory-utilization.
      gpuMemoryUtilizationBufferPercent: 10
  inPlaceResize:
    # Use the restart/eviction flow instead of in-place pod resize.
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
kind: ClusterGpuReactivePolicy
metadata:
  name: kai-gpu-sharing-reactive
spec:
  experimental:
    # Required contract version for the current experimental GPU/KAI integration.
    gpuKaiContract: v1alpha1-2026-07
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
        # Cap each increase at 2x the current requested GPU fraction.
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
        # Cap each increase at 2x the current requested GPU fraction.
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
        # For example, if the current KAI allocation is 0.30 and the pod uses 15% of the whole GPU, the metric will show 50% usage.
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
- In-place resizing for KAI-enabled workloads is experimental and currently unstable.

## vLLM tuning with KAI gpu-fraction

If a pod starts a vLLM server, AutomationStrategy admission mutation can tune `--gpu-memory-utilization` based on the admitted KAI `gpu-fraction`.

For example:

- The admitted `gpu-fraction` is `0.5`.
- `spec.kai.vllm.gpuMemoryUtilizationBufferPercent` is `10`.
- The resulting vLLM argument is `--gpu-memory-utilization=0.45`.

Behavior:

- Runs only during KAI GPU request admission mutation.
- Mutates only detected vLLM containers.
- Updates existing `--gpu-memory-utilization=<value>` flags.
- Updates existing split-form `--gpu-memory-utilization <value>` flags.
- Appends the flag when it is missing.
- Does not create duplicate flag entries.

## Existing KAI Installations

For workloads that are already scheduled through KAI, these policies will:

- Keep the existing `kai.scheduler/queue` label on the workload template.
- Allow Kubex Automation Engine to update `gpu-fraction` as policies are applied.

That allows Kubex Automation Engine to participate in GPU sharing without taking over queue assignment.

If you want Kubex to overwrite an existing `kai.scheduler/queue` label, set `spec.kai.setQueueWhenSpecified: true` in your AutomationStrategy.

For workloads that are not currently scheduled through KAI, these policies will:

- Replace the `nvidia.com/gpu` resource allocation with KAI `gpu-fraction` annotations.
- Apply the KAI queue `kubex-unlimited-gpu-queue` (the Kubex-built-in KAI queue that does not perform quota allocations).

## KAI node consolidation

`GpuConsolidationPolicy` is cluster-scoped and works separately from `AutomationStrategy`. Use it to identify underutilized GPU nodes within a single compatible node pool and evict pods from a node only when the controller believes all `gpu-fraction` pods on that node can fit elsewhere in the same pool.

Start with one narrowly scoped policy per compatibility pool:

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: GpuConsolidationPolicy
metadata:
  name: gpu-consolidation-pool-a
spec:
  experimental:
    gpuKaiContract: v1alpha1-2026-07
  nodeSelector:
    matchLabels:
      cloud.google.com/gke-accelerator: nvidia-tesla-t4
  utilizationThresholdPercent: 75
  requeueAfter: 1m
```

If you have multiple GPU compatibility pools, create multiple policies instead of one broad selector. For example, keep `nvidia-tesla-t4` nodes separate from `nvidia-l4` nodes or from a different provider-specific GPU node class.

### Node consolidation limitations

GPU node consolidation is experimental and has known limitations.

- It assumes pods will be schedulable on other nodes if they fit by GPU fraction.
- It does not yet fully model all other scheduler constraints.
- That can lead to frequent evictions when the controller chooses a node that looks drainable from GPU capacity alone but cannot actually be rescheduled cleanly.
- It may behave unpredictably with nodes that have multiple GPUs.

Use it carefully and start with a narrowly scoped worker pool.
