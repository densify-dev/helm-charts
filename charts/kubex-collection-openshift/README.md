# Kubex Automation Stack Helm Chart for OpenShift Clusters

<picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://kubex.ai/wp-content/uploads/kubex-logo-reverse-landscape.svg">
    <source media="(prefers-color-scheme: light)" srcset="https://kubex.ai/wp-content/uploads/kubex-logo-landscape.svg">
    <img src="https://kubex.ai/wp-content/uploads/kubex-logo-landscape.svg" width="300">
</picture>

## Introduction

Densify's Kubex analyses Kubernetes clusters and produces recommendations for rightsizing resources to mitigate risk and reduce waste. 

OpenShift clusters have restrictions which do not allow the usage of the general-purpose [Kubex automation stack helm chart](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack). This chart replaces it.

This chart requires very minimal configuration in order to install the entire stack. All of it is in `values-edit.yaml`.

## Prerequisites

1. OpenShift cluster
2. Environment with the following:
   - `kubectl`
   - `helm`

## Installation

The installation on an OpenShift cluster is straight-forward.

### Steps

To deploy the Kubex stack, follow these steps below:

1. Download [values-edit.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-collection-openshift/values-edit.yaml).

2. Edit `values-edit.yaml` with the relevant mandatory parameters as described in [Configuration](#configuration) and save it.

3. If your cluster has arm64 architecture, download also [values-arm64.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-collection-openshift/values-arm64.yaml).

4. To add the helm repos, run:

```shell
helm repo add kubex https://densify-dev.github.io/helm-charts
helm repo update
```

5. To install the chart

- On an amd64 cluster, run:

    ```shell
    helm upgrade --install -n kubex --create-namespace -f values-edit.yaml kubex kubex/kubex-collection-openshift
    ```

- On an arm64 cluster, run:

    ```shell
    helm upgrade --install -n kubex --create-namespace -f values-arm64.yaml -f values-edit.yaml kubex kubex/kubex-collection-openshift
    ```

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

## Further Details

This chart consists of two subcharts:

* [Kubex Container Optimization Data Forwarder](../container-optimization-data-forwarder), which collects data and forwards it to a Kubex instance for analysis

## Documentation

* [Kubex](https://www.kubex.ai/product/kubernetes-resource-optimization/)

## License

Apache 2 Licensed. See [LICENSE](LICENSE) for full details.
