# Kubex Automation Stack Helm Chart for GKE Autopilot Clusters

<picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://www.kubex.ai/wp-content/uploads/kubex-by-densify-logo-reverse.png">
    <source media="(prefers-color-scheme: light)" srcset="https://www.kubex.ai/wp-content/uploads/kubex-by-densify-logo.png">
    <img src="https://www.kubex.ai/wp-content/uploads/kubex-by-densify-logo.png" width="300">
</picture>

## Introduction

Kubex analyses Kubernetes clusters and produces recommendations for rightsizing resources to mitigate risk and reduce waste. 

GKE Autopilot clusters have restrictions which do not allow the usage of the general-purpose [Kubex Automation Stack helm chart](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack). This chart replaces it.

This chart requires very minimal configuration in order to install the entire stack. All of it is in `values-edit.yaml`.

## Prerequisites

1. GKE Autopilot cluster
2. Linux environment with the following:
   - `bash`
   - `gcloud`
   - `kubectl`
   - `helm`

## Installation

Whereas it is possible to run the commands manually and separately, it is highly recommended to use the provided shell script [deploy.sh](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-collection-gke-autopilot/deploy.sh). This script uses `gcloud` CLI to take care of various scenarios, and makes sure the GKE cluster can be used and the required GCP service account is present and has the required IAM policy bindings.

### Steps

To deploy the Kubex stack, follow these steps below:

1. Download [values-edit.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-collection-gke-autopilot/values-edit.yaml).

2. Edit `values-edit.yaml` with the relevant mandatory parameters as described in [Configuration](#configuration).

3. If your cluster has arm64 architecture, download also [values-arm64.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-collection-gke-autopilot/values-arm64.yaml).

4. Download [deploy.sh](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-collection-gke-autopilot/deploy.sh).

5. To add the helm repos, run:

```shell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add densify https://densify-dev.github.io/helm-charts
helm repo update
```

6. Run `deploy.sh` according to its [usage](#usage).

### Usage

`deploy.sh` usage options are described in the following table:

| Option | Mandatory | Description | Default |
| :--- | :---: | :--- | :--- |
| `-g <GKE_CLUSTER_NAME>` | :white_check_mark: | The GKE cluster name | |
| `-r <GCP_REGION>` | [^1](#region-zone-note) | The GCP region | |
| `-z <GCP_ZONE>` | [^1](#region-zone-note) | The GCP zone | |
| `-k <KUBEX_CLUSTER_NAME>` | | The Kubex cluster name | Same as `GKE_CLUSTER_NAME` |
| `-a <ARCH>` | | The architecture (`amd64`/`arm64`) | `amd64` |
| `-n` | | Deploy Kubex data collection on a non-GKE cluster to collect data from Google Managed Prometheus for a GKE cluster | |
| `-h` | | Print the usage and exit | |

<span id="region-zone-note">[^1]</span> <small>Exactly ONE of `GCP_REGION` or `GCP_ZONE` is required (depending if the GKE cluster is regional or zonal), but NOT both.</small>

## Configuration

The following table lists configuration parameters in `values-edit.yaml`.

| Parameter                                                                        | Mandatory          | Description                                            |
| -------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------ |
| `stack.densify.username`                                                         | :white_check_mark: | Kubex user account                                   |
| `stack.densify.encrypted_password`                                               | :white_check_mark: | Encrypted password for the Kubex User                |
| `container-optimization-data-forwarder.`<br/>`config.forwarder.densify.url.host` | :white_check_mark: | Kubex instance hostname (`< instance >.kubex.ai`) |
| `container-optimization-data-forwarder.`<br/>`config.clusters[0].name`           | :white_check_mark: | Cluster name **(must be unique, customer-wide; if not, specify an alternate name)** |
| `container-optimization-data-forwarder.`<br/>`cronJob.successfulJobsHistoryLimit` |                    | Number of successful jobs to keep |
| `container-optimization-data-forwarder.`<br/>`cronJob.failedJobsHistoryLimit` |                    | Number of failed jobs to keep |
| `container-optimization-data-forwarder.`<br/>`cronJob.ttlSecondsAfterFinished` |                    | TTL to keep jobs after completion/failure |
| `container-optimization-data-forwarder.`<br/>`cronJob.backoffLimit` |                    | Backoff limit for jobs |
| `prometheus.server.persistentVolume.`<br/>`storageClass`                         |                    | Storage class for Prometheus persistent volume |

## Limitations

* Supported architectures: amd64 (x64), arm64
* Release name: the helm chart release name **must** be set to `kubex` to ensure interdependencies are met
* **Node metrics**: GKE Autopilot does not permit rollout of node exporter, which provides many of the node, node group and cluster metrics, as node exporter requires privileges to collect these metrics and these privileges are forbidden by Autopilot; as a result, many node, node group and clusters metrics are missing (CPU, memory, network and disk metrics)
* **GPU metrics**: however, if your GKE Autopilot cluster has workloads which use Nvidia GPUs, GKE Autopilot rolls out Nvidia's DCGM exporter and this helm chart makes sure that the GPU metrics are being properly collected

## Further Details

This chart consists of two subcharts:

* [Kubex Data Collector](../container-optimization-data-forwarder), which collects data and forwards it to a Densify instance for analysis

* [Prometheus Community kube-state-metrics chart](https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-state-metrics/) which deploys kube-state-metrics with the requirements of Kubex data collection (the default rollout of kube-state-metrics in GKE Autopilot clusters lacks a lot of metrics required by Kubex)

## Documentation

* [Kubex](https://www.kubex.ai)

## License

Apache 2 Licensed. See [LICENSE](LICENSE) for full details.
