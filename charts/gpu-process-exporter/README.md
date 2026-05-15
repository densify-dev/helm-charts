# Kubex GPU Process Exporter Helm Chart

<picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://kubex.ai/wp-content/uploads/kubex-logo-reverse-landscape.svg">
    <source media="(prefers-color-scheme: light)" srcset="https://kubex.ai/wp-content/uploads/kubex-logo-landscape.svg">
    <img src="https://kubex.ai/wp-content/uploads/kubex-logo-landscape.svg" width="300">
</picture>

## Purpose

This chart deploys the Kubex GPU process exporter. This exporter addresses the limitations of Nvidia's [DCGM Exporter](https://github.com/NVIDIA/dcgm-exporter) in providing container-level metrics.

## Motivation

The DCGM exporter collects metrics per GPU device, but comes short associating the utilization metrics with the specific container which actually uses the GPU. To do this, the DCGM exporter relies on the [Nvidia device plugin](https://github.com/NVIDIA/k8s-device-plugin). This association has the following issues:

* A basic assumption of the DCGM exporter is that ALL metrics of the device can (and should) be mapped to a **single** container using it. This assumption breaks in the case that the GPU is shared by multiple containers; it is also not the right approach for some metrics (non-utilization), which should not be mapped to containers.
* The DCGM exporter cannot deal with "soft" (software-based) GPU sharing techniques, such as time-slicing or MPS. With each datapoint the exporter randomly reports one of the containers using the GPU simultaneously, and attributes all the utilization to this container.
* The DCGM exporter also cannot deal with [KAI scheduler](https://github.com/kai-scheduler/KAI-Scheduler), which sets "reservation containers" to reserve the GPU, and schedules the actual workloads to utilize it.

The Kubex GPU process exporter addresses these limitations.

## Prerequisites

* A k8s cluster with at least one Nvidia GPU
* All nodes with Nvidia GPUs have to be labeled `nvidia.com/gpu.present=true` (typically done by the [Nvidia GPU OPerator](https://github.com/nvidia/gpu-operator))

## Details

Deploys a DaemonSet with the following requirements:

* RBAC: `Pods - get, list, watch`
* access to `hostPID`
* security context: `privileged` container (runs as root)
* read-only access to the node's `/` filesystem
* read-only access to the node's `/proc` filesystem

## Configuration

The following table lists configuration parameters in values.yaml and their default values.

| Parameter | Mandatory | Description | Default |
| --- | --- | --- | --- |
| `image.repository` |  | Exporter image repository. | `densify/gpu-process-exporter` |
| `image.tag` | :white_check_mark: | Exporter image tag. |  |
| `image.pullPolicy` |  | Exporter image pull policy. | `Always` |
| `serviceAccount.create` |  | Create a service account for the exporter. |  |
| `serviceAccount.name` | Required when `serviceAccount.create` is `false`. | Service account name to use. | `gpu-process-exporter` |
| `rbac.create` |  | Create RBAC resources for Pod read access. |  |
| `rbac.clusterRoleName` |  | Name of the ClusterRole to create or bind. | `gpu-exporter-role` |
| `rbac.clusterRoleBindingName` |  | Name of the ClusterRoleBinding to create. | `gpu-exporter-binding` |
| `prometheusScrape.annotate` |  | Add Prometheus scrape annotations to the Service (typically used by [prometheus-community/prometheus helm chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus)). |  |
| `prometheusScrape.interval` |  | Scrape interval - should match the actual scrape interval of Prometheus (global or explicit) for this exporter. Passed to the exporter as `SCRAPE_INTERVAL` environment variable. | `20s` |
| `port` |  | Container and Service metrics port. | `9494` |
| `service.type` |  | Kubernetes Service type. | `ClusterIP` |
| `service.annotations` |  | Additional annotations to add to the Service. |  |
| `hostProcMount` |  | Host path mounted into the exporter as `/host/proc`. See [here](#kind-clusters-and-proprietary-driver). | `/proc` |
| `nvmlSearchPath` |  | Override path used by the exporter to find NVML shared libraries. See [here](#non-standard-nvml-so-files-location). |  |

### Kind clusters and proprietary driver

The `hostProcMount` parameter is **only** required in case of a [kind](https://kind.sigs.k8s.io/) k8s cluster running on a host with a **proprietary** Nvidia driver (e.g. the series of `linux-modules-nvidia-<version>-server-generic` on Ubuntu). The reason for that is that `kind` nodes are Docker containers, and the proprietary Nvidia driver was blocked from understanding the Linux PID namespaces (by calling GPL-only functions), so it only has access to the host PIDs (which do not match the node's PIDs).

This parameter is **NOT** required if the cluster is NOT a `kind` cluster, or if the Nvidia driver uses the newer **Open GPU Kernel Modules** architecture (e.g. the series of `linux-modules-nvidia-<version>-server-open-generic` on Ubuntu), which is permitted access to these GPL-only functions and Linux PID namespaces.

If you have a `kind` cluster and a **proprietary** Nvidia driver, you need to deploy your cluster as follows:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
  extraMounts:
  - hostPath: /dev/null
    containerPath: /var/run/nvidia-container-devices/all
  - hostPath: /proc
    containerPath: /physical-host-proc
    readOnly: true
```

And then specify the parameter `hostProcMount: /physical-host-proc` in the values. This makes sure that the exporter has access to the **host's** `/proc` filesystem.

### Non-standard NVML .so files location

The exporter is required to load the NVML .so files from the **node's filesystem**. This makes sure that the right NVML version which matches the driver is loaded.

The exporter is configured to look by default for well-known standard locations of the NVML .so files as follows:

(`${DEBIAN_LIB_ARCH}` is one of `x86_64-linux-gnu` or `aarch64-linux-gnu`).

| Location | CSP / OS / Installation |
| --- | --- |
| `/home/kubernetes/bin/nvidia/lib64` | GKE COS / GKE GPU Operator with Google driver installer |
| `/opt/nvidia/lib64` | GKE Ubuntu Google driver installer |
| `/usr/local/nvidia/lib64` | NVIDIA container runtime / GKE exposed driver path / kind and nvkind |
| `/run/nvidia/driver/usr/lib64` | NVIDIA GPU Operator driver container, RPM-style |
| `/run/nvidia/driver/usr/lib/${DEBIAN_LIB_ARCH}` | NVIDIA GPU Operator driver container, Debian-style |
| `/usr/lib/${DEBIAN_LIB_ARCH}` | Ubuntu/Debian (GKE Ubuntu, AKS Ubuntu, OKE Ubuntu, kind) |
| `/usr/lib64` | EKS Amazon Linux, AKS Azure Linux, OKE Oracle Linux, Bottlerocket |
| `/lib/${DEBIAN_LIB_ARCH}` | Debian/Ubuntu merged-/usr compatibility |
| `/lib64` | RPM-style compatibility |

If your k8s cluster nodes have a non-standard location for the NVML .so files, the parameter `nvmlSearchPath` is required and should be set this location, as it is mounted under `/host/root/...` . In this case the standard locations are not searched.

---

## Limitations

* Supported architectures: amd64 (x64), arm64

## Documentation

* [Kubex](https://www.docs.kubex.ai)

## License

Apache 2 Licensed. See [LICENSE](LICENSE) for full details.
