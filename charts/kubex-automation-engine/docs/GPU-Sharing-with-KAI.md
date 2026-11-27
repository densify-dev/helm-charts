# GPU Sharing with KAI

Kubex Automation Engine manages GPU requests and limits for native NVIDIA resources and KAI sharing. KAI schedules shared workloads, GPU Fractioning enforces NvFractions memory allocations at container creation, and Kubex selects sizes from recommendations and metrics. Native NVIDIA and HAMi-core use equal requests and limits; NVIDIA GPU Fractioning supports separate memory requests and limits.

> [!IMPORTANT]
> NvFractions is experimental and its KAI release is still unresolved. The intended combination is KAI `vX.Y.Z` with GPU Fractioning `0.1.9`, not a validated installation command. This warning applies only to NvFractions; the established [HAMi-core path](#hami-core-alternative) uses KAI `v0.17.0` and HAMi-core `1.1.0-chart`.

> NvFractions release follow-up: Before publishing that path, replace `vX.Y.Z` throughout the NvFractions docs and examples with the KAI release incorporating [API PR 28](https://github.com/kai-scheduler/api/pull/28), then verify its versioned links and bundled GPU Fractioning compatibility. That release has not yet been validated here.

## Before you start

- Prepare a working GPU pool and a matching KAI backend. For NvFractions, check the [backend prerequisites](#1-choose-an-eligible-backend), [runtime preparation](#2-prepare-gpu-operator-and-the-runtime), and [readiness checks](#3-install-kai-and-check-readiness) below. Keep existing Helm/GitOps settings and plan runtime changes as maintenance.
- Use one GPU container on one device per Pod. For `sm-sharing`, provide working NVIDIA MPS and compatible workload placement.
- Label each target Deployment's metadata with `nvidia.com/gpu.present: "true"`. Both policies select matching Deployments across all namespaces.
- Supply fresh, automation-enabled Kubex recommendation data with `gpu.gpuOverallOptimal` for its GPU container.
- Supply both compute and memory metrics with the configured namespace, Pod, and container labels. The `kubex_gpu_container_*` names below are site-defined placeholders, not shipped metrics or recording rules. Implement and verify the [Prometheus metric contract](./gpu-reactive-policies.md#prometheus-metric-prerequisites) before enabling the reactive policy.

### Enable the Kubex webhook and queue

Add the following values to your `kubex-automation-stack` deployment:

```yaml
kubex-automation-engine:
  enabled: true
  webhook:
    podMutation:
      additionalWebhook:
        enabled: true
  kaiQueues:
    enabled: true
```

## Proactive + reactive starter

This starter uses a cluster-scoped strategy and two policies targeting Deployments in all namespaces with `nvidia.com/gpu.present: "true"` on the Deployment's metadata. Set that label on the workload itself; GPU-node discovery labels do not automatically label Deployments.

Save the following as `gpu-sharing.yaml` after configuring the metric prerequisites above, then apply it with `kubectl apply -f gpu-sharing.yaml`. It targets an existing workload, not a demo Deployment.

```yaml
# Strategy shared by the baseline and reactive policies below.
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterAutomationStrategy
metadata:
  name: kai-gpu-sharing
spec:
  enablement:
    overrideScheduler: kai
    gpu:
      requests:
        downsize: true
        upsize: true
        setFromUnspecified: true
        ceiling: "0.99999"
      limits:
        downsize: true
        upsize: true
        setFromUnspecified: true
        ceiling: "0.99999"
  kai:
    gpuSharingMode: NvFractions
    gpuComputeMode: sm-sharing
    setQueueWhenSpecified: false
  inPlaceResize:
    # Use the restart/eviction flow instead of in-place Pod resize.
    enabled: false
  podEviction:
    # Permit eviction when applying a new size.
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
        # Select Deployment metadata, not node or Pod-template labels.
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
  # Wait for each Pod to build at least 10 minutes of metrics.
  minPodMetricsAge: 10m
  metrics:
    compute:
      upsize:
        # Increase the GPU fraction when compute usage reaches the current request.
        thresholdPercent: 100
        # Base the upsize decision on the most recent 2 minutes of samples.
        metricsWindow: 2m
        # Add 20% headroom above observed compute usage.
        headroomPercent: 20
        # Cap growth at twice the stored baseline, not each successive allocation.
        maxPercent: 200
      scaleBack:
        # Reduce the GPU fraction only after compute usage stays below 75%.
        thresholdPercent: 75
        # Require 10 minutes of lower usage before scaling back.
        metricsWindow: 10m
        # Keep 20% spare compute capacity after scaling back.
        headroomPercent: 20
      prometheus:
        # Metric and label mapping used to join compute samples to containers.
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
        # Add 20% headroom above observed memory usage.
        headroomPercent: 20
        # Cap growth at twice the stored baseline, not each successive allocation.
        maxPercent: 200
      scaleBack:
        # Reduce the GPU fraction only after memory usage stays below 75%.
        thresholdPercent: 75
        # Require 10 minutes of lower usage before scaling back.
        metricsWindow: 10m
        # Keep 20% spare memory capacity after scaling back.
        headroomPercent: 20
      prometheus:
        # Metric and label mapping used to join memory samples to containers.
        metric: kubex_gpu_container_memory_footprint_percent
        # Use only for metrics normalized to the current request, not a burst limit.
        # A request of 0.30 using 15% of the whole GPU reports 50% usage.
        interpretation: currentAllocation
        namespaceLabel: namespace
        podLabel: pod
        containerLabel: container
  automationStrategyRef:
    name: kai-gpu-sharing
```

## Verify the result

After a successful change, replacement Pods use the KAI scheduler and have a `kai.scheduler/queue` label. Unless already assigned a queue, they use `kubex-unlimited-gpu-queue`. Check the `gpu-fraction`, translated GPU memory annotations, and selected compute mode on the new Pod. 

If nothing changes, check that Kubex has recommendations for the containers, both metrics have samples attributed to the correct container, and workload labels and namespace match both policies. Events and controller logs can identify PDB, readiness, or other eviction safety checks delaying replacement. Do not test resizing by patching annotations on a running Pod, when configured right, it will be done automatically.

## What happens after applying the starter

The strategy selects KAI behavior and permits changes; policies supply the targets. Proactive sizing requires fresh, automation-enabled Kubex data for the targeted container. Proactive policies can also apply CPU and memory recommendations under the strategy's defaults; this is not a GPU-only policy.

The reactive policy waits until Pods are at least `10m` old. For both compute and memory, it checks a `2m` upsize window against a `100%` threshold and adds `20%` headroom. `maxPercent: 200` caps growth at twice the stored baseline, not twice each successive allocation. Scale-back requires all eligible Pods to stay below `75%` over `10m`, keeps `20%` headroom, and does not go below the baseline. The higher compute or memory target wins. Accounting uses the request, not a burst limit.

### Annotation and restart semantics

- Kubex will set the following annotations: `gpu-fraction` to specify the request and `gpu-fraction.limit` to specify a bursting limit. The limit is only enforced on memory, compute is fair-share.
- One GPU container on one device is supported. Absolute-memory automation is not supported.

### Compute sharing

`spec.kai.gpuComputeMode` accepts `time-slicing` or `sm-sharing` with `gpuSharingMode: NvFractions`. The strategy value takes precedence over a workload's `nvidia.com/container.<name>.gpu-compute.mode` annotation on admission. When left to defaults, Kubex preserves the workload annotation or leaves it absent so KAI defaults to time-slicing. The field is only supported with NvFractions and `overrideScheduler: kai`. The example sets it explicitly so its compute behavior is clear.

Changing only the compute mode does not evict existing Pods. The change takes effect on newly admitted or otherwise replaced Pods. A running container's annotations do not reconfigure its CUDA context.

SM sharing requires a working NVIDIA MPS setup. Treat MPS startup or CUDA context errors as runtime failures to investigate, not as evidence that memory limits are wrong. MPS clients can share a fatal-error domain, so SM sharing is not a tenant security boundary. Place compatible workloads in a dedicated GPU pool with node selectors and tolerations; Kubex does not select a compatible GPU placement or provision MPS for you.

Existing `kai.scheduler/queue` labels are preserved unless `spec.kai.setQueueWhenSpecified: true`. When converting native GPU resources to KAI, Kubex removes `nvidia.com/gpu` requests/limits and applies the strategy queue if none is present.


### Consolidation

[GPU Reactive Policies](./gpu-reactive-policies.md) generate equal explicit GPU request and limit targets. They do not enforce memory or generate burst capacity. With NvFractions, selecting that equal pair replaces any old burst allocation with a fixed allocation. Enable every changing member, including limit downsize when removing an old burst limit. Configure eviction-based resize as above. Use `prometheus.interpretation: fullGPU` for metrics expressed relative to the physical GPU. Use `currentAllocation` only for metrics normalized to the current **request**, not the burst limit.

`GpuConsolidationPolicy` accounts for requests, not opportunistic limits. Start with one narrow node selector per compatible GPU pool. Consolidation does not model every scheduler constraint and may cause repeated evictions or behave unpredictably on multi-GPU nodes. See [GPU consolidation policies](./gpu-consolidation-policy.md).

## Install GPU Fractioning with KAI

Kubex does not install KAI, the GPU Operator, or GPU Fractioning. Prepare these separately before enabling policies.

The steps below are based off NVIDIA's public instructions for installing the gpu-operator and KAI. Kubex works with existing or new installations of these components, as long as they are on the correct versions listed below and configured with the appropriate values to enable NvFractions.

### 1. Choose an eligible backend

Check every NvFractions prerequisite before installing it:

1. Kubernetes 1.28+ and cgroup v2 on every eligible GPU node.
2. containerd 2.0+ with NRI enabled, or supported CRI-O with NRI support.
3. NVIDIA GPU Operator `26.7.1` or newer, container toolkit `1.20.1` or newer, and device plugin `0.20.1` or newer. Check pinned operand versions too, not just the Operator version.
4. NVIDIA driver r615 or newer with CUDA 13.4 support on every eligible GPU node. The Operator default does not supply r615.
5. Physical GPU capacity without NVIDIA device-plugin time-slicing replicas. KAI does not support that replicas setting.

If **any** prerequisite is unmet or cannot be confirmed, stop the NvFractions path and follow the complete [HAMi-core installation](#hami-core-alternative) instead. HAMi still needs a working NVIDIA runtime and physical GPU capacity without time-slicing replicas. Do not bypass GPU Fractioning dependency checks to make an unsupported stack appear ready.

### 2. Prepare GPU Operator and the runtime

**For a fresh GPU Operator installation**:

```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update
export NVIDIA_DRIVER_VERSION='620.70.06' # replace with a different version if necessary. driver must provide CUDA 13.4 or newer.
helm install gpu-operator nvidia/gpu-operator \
  --namespace kube-system --version v26.7.1 \
  --set-string driver.version="$NVIDIA_DRIVER_VERSION"
```

**For an existing Helm installation**, update the following Helm value in your existing installation and ensure you use NVIDIA GPU Operator >= `26.7.1`. Review incompatible overrides before upgrading. If drivers are managed outside Helm, upgrade them through that mechanism instead of enabling Operator driver management.

```yaml
driver:
  version: 615.92
```

### 3. Install KAI and check readiness

The following NvFractions installation snippet is illustrative and non-executable pending KAI release validation. `vX.Y.Z` is an unresolved placeholder, not an available release. Before publishing executable instructions, validate the selected release's subcharts.yaml and confirm its bundled GPU Fractioning compatibility with the intended `0.1.9` version.

```bash
# Illustrative only; do not run. KAI release vX.Y.Z has not been validated.
helm upgrade --install kai-scheduler oci://ghcr.io/kai-scheduler/kai-scheduler/kai-scheduler \
  --namespace kai-scheduler --create-namespace \
  --version vX.Y.Z \
  --set global.nvFractions.set=true
```

For existing KAI releases, securely back up and preserve reviewed Helm/GitOps values when upgrading; merge the mode setting into those values rather than replacing them with this minimal command. KAI sharing mode describes the installed cluster backend, not a per-Pod backend choice.

Keep KAI's validating admission enabled with `failurePolicy: Fail`. Before uninstalling an existing release, securely save `GpuFractioningConfig/default` and inspect its owner references. Uninstalling KAI can garbage-collect that configuration and its daemons. Restore the saved spec after reinstalling if the default configuration is absent, then wait for readiness again.

Require `GpuFractioningConfig/default` condition `Ready=True` and node condition `gpu-fractioning.nvidia.com/Ready=True`. Do not bypass dependency or readiness checks.

## HAMi-core alternative

Use this path if any NvFractions prerequisite is unmet. It does not require GPU Fractioning, r615, or runtime NRI, but does require supported NVIDIA drivers, a working NVIDIA container runtime/device plugin, GPU node discovery labels, and physical GPU capacity without time-slicing replicas. Verify native CUDA access before proceeding.

Keep your existing working GPU Operator/runtime installation. If none is installed, install it first, selecting a driver supported by your GPU and OS:

```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update
helm install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator --create-namespace --version v26.7.1
kubectl get clusterpolicy -o yaml
kubectl -n gpu-operator get pods
kubectl get nodes -l nvidia.com/gpu.present=true
kubectl get runtimeclass
```

Follow the [GPU Operator platform requirements](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/26.7/getting-started.html) for externally managed drivers and runtimes. Do not install a second Operator over a managed GPU stack. Confirm native CUDA workloads work first. Disable NVIDIA device-plugin time-slicing replicas so KAI sees physical GPU capacity. The libsync DaemonSet below must cover every eligible GPU node with `nvidia.com/gpu.present=true`. Confirm that label and runtime access on every such node.

Install the isolator and KAI using the established KAI `v0.17.0` HAMi-core configuration. Preserve reviewed user values when upgrading existing releases; do not use this command to switch an active NvFractions cluster without a migration plan.

Create `kai-scheduler.values.yaml`:

```yaml
binder:
  cdiEnabled: true
  plugins:
    hamicore:
      enabled: true
global:
  clusterAutoscaling: true
  gpuSharing: true
```

KAI `v0.17.0` uses `binder.cdiEnabled`, not `binder.additionalArgs`, to enable CDI. Its chart does not use the newer `global.gpuSharingMode` or `global.nvFractions.set` values. HAMi-core enforces GPU memory allocations for CUDA workloads; reactive policies resize allocations but do not enforce memory limits.

Install HAMi-core first, then KAI:


```bash
helm upgrade --install kai-resource-isolator oci://docker.io/projecthami/kai-resource-isolator \
  --namespace kai-resource-isolator --create-namespace --version 1.1.0-chart \
  --set-string 'librarySync.nodeSelector.nvidia\.com/gpu\.present=true'
helm upgrade --install kai-scheduler oci://ghcr.io/kai-scheduler/kai-scheduler/kai-scheduler \
  --namespace kai-scheduler --create-namespace --version v0.17.0 \
  -f kai-scheduler.values.yaml
kubectl -n kai-resource-isolator get daemonset kai-resource-isolator-libsync
```

Check readiness and webhook installation:

```bash
kubectl -n kai-resource-isolator rollout status daemonset/kai-resource-isolator-libsync --timeout=300s
kubectl -n kai-resource-isolator get deploy,ds,pods
kubectl get mutatingwebhookconfiguration kai-resource-isolator-mutating
kubectl -n kai-scheduler get pods
kubectl get runtimeclass
```

The libsync DaemonSet's `DESIRED`, `CURRENT`, and `READY` counts must cover all eligible GPU nodes. Check that the KAI configuration has GPU sharing and the HAMi-core binder plugin enabled:

```bash
kubectl get configs.kai.scheduler -o yaml
```

Then enable the [Kubex webhook and queue](#enable-the-kubex-webhook-and-queue). Use the [proactive + reactive starter](#proactive--reactive-starter) with `gpuSharingMode: HamiCore` and omit `gpuComputeMode`. Its equal targets suit HAMi-core; GPU Fractioning readiness checks do not apply.

In Kubex strategies use `kai.gpuSharingMode: HamiCore` and enable the desired GPU request and limit changes. Kubex writes fractions to `gpu-fraction` and `gpu-fraction.limit`. Unequal or incomplete pairs do not automate GPU resources.
