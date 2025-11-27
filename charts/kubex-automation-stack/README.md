# Kubex Automation Stack Helm Chart

<picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://www.densify.com/wp-content/uploads/kubex-by-densify-logo-reverse.png">
    <source media="(prefers-color-scheme: light)" srcset="https://www.densify.com/wp-content/uploads/kubex-by-densify-logo.png">
    <img src="https://www.densify.com/wp-content/uploads/kubex-by-densify-logo.png" width="300">
</picture>

## Introduction

Densify's Kubex analyses Kubernetes clusters and produces recommendations for rightsizing resources to mitigate risk and reduce waste. This chart includes all components required for that.

This chart requires very minimal configuration in order to install the entire stack. All of it is in `values-edit.yaml`.

## Installation

To deploy the Kubex stack, follow these steps below:

1. Determine your sizing file as described in [Sizing](#sizing) and download it.

2. Download [values-edit.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/values-edit.yaml).

3. Edit `values-edit.yaml` with the relevant mandatory parameters as described in [Configuration](#configuration).

4. If your cluster has arm64 architecture, download also [values-arm64.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/values-arm64.yaml).

5. To add the helm repos, run:

```shell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add densify https://densify-dev.github.io/helm-charts
helm repo update
```

6. If your cluster has amd64 architecture, run this command:

```shell
helm install --create-namespace -n densify -f values-edit.yaml -f <sizing file> kubex densify/kubex-automation-stack
```

7. If your cluster has arm64 architecture, run this command:

```shell
helm install --create-namespace -n densify -f values-edit.yaml -f <sizing file> -f values-arm64.yaml kubex densify/kubex-automation-stack
```

## Sizing

The following table indicates - depending on the cluster size - which sizing file to use initially. Please note that these are initial sizing settings, once Kubex is running long enough and producing rightsizing recommendations for the stack components, these recommendations should be implemented for optimization.

| Cluster Size    | No. of Containers | Sizing File to Use |
| --------------- | ----------------- | ------------------ |
| Small           | 0-5000            | [values-small.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/values-small.yaml) |
| Medium          | 5001-10000        | [values-medium.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/values-medium.yaml) |
| Large           | 10001+            | [values-large.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/values-large.yaml) |

## Configuration

The following table lists configuration parameters in `values-edit.yaml`.

| Parameter                                                                        | Mandatory          | Description                                            |
| -------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------ |
| `stack.densify.username`                                                         | :white_check_mark: | Densify user account                                   |
| `stack.densify.encrypted_password`                                               | :white_check_mark: | Encrypted password for the Densify User                |
| `container-optimization-data-forwarder.`<br/>`config.forwarder.densify.url.host` | :white_check_mark: | Densify instance hostname (`< instance >.densify.com`) |
| `container-optimization-data-forwarder.`<br/>`config.clusters[0].name`           | :white_check_mark: | Cluster name **(must be unique, customer-wide; if not, specify an alternate name)** |
| `container-optimization-data-forwarder.`<br/>`cronJob.successfulJobsHistoryLimit` |                    | Number of successful jobs to keep |
| `container-optimization-data-forwarder.`<br/>`cronJob.failedJobsHistoryLimit` |                    | Number of failed jobs to keep |
| `container-optimization-data-forwarder.`<br/>`cronJob.ttlSecondsAfterFinished` |                    | TTL to keep jobs after completion/failure |
| `prometheus.server.persistentVolume.`<br/>`storageClass`                         |                    | Storage class for Prometheus persistent volume |

## Limitations

* Supported architectures: amd64 (x64), arm64
* Release name: the helm chart release name **must** be set to `kubex` to ensure interdependencies are met

## Further Details

This chart consists of two subcharts:

* [Densify Container Optimization Data Forwarder](../container-optimization-data-forwarder), which collects data and forwards it to a Densify instance for analysis

* [Prometheus Community Prometheus chart](https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus/) which contains the entire stack required for the Densify Forwarder to collect data

## Documentation

* [Kubex](https://www.densify.com/product/kubernetes-resource-optimization/)

## License

Apache 2 Licensed. See [LICENSE](LICENSE) for full details.
