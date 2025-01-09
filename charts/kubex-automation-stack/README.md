# Kubex Container Optimization Stack Helm Chart

<picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://kubex.ai/wp-content/uploads/kubex-logo-reverse.png">
    <source media="(prefers-color-scheme: light)" srcset="https://kubex.ai/wp-content/uploads/kubex-logo.png">
    <img src="https://kubex.ai/wp-content/uploads/kubex-logo.png" width="300">
</picture>

## Introduction

This chart includes the following subcharts:

* [Densify Container Optimization Data Forwarder](../container-optimization-data-forwarder), which collects data and forwards it to a Densify instance for analysis

* [Prometheus Community Prometheus chart](https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus/) which contains the entire stack required for the Densify Forwarder to collect data

## Details

This chart requires very minimal configuration in order to install the entire stack. All of it is in `values-edit.yaml`.

## Installation

To deploy the Kubex stack, follow these steps below:

1. Download [values-edit.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/values-edit.yaml).

2. Edit `values-edit.yaml` with the relevant mandatory parameters as described in [Configuration](#configuration).

3. Run:

```shell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add densify https://densify-dev.github.io/helm-charts
helm repo update
helm install --create-namespace -n densify -f values-edit.yaml kubex densify/kubex-automation-stack
```

## Configuration

The following table lists configuration parameters in values.yaml and their default values.

| Parameter                                                                        | Mandatory          | Description                                            |
| -------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------ |
| `stack.densify.username`                                                         | :white_check_mark: | Densify user account                                   |
| `stack.densify.encrypted_password`                                               | :white_check_mark: | Encrypted password for the Densify User                |
| `container-optimization-data-forwarder.`<br/>`config.forwarder.densify.url.host` | :white_check_mark: | Densify instance hostname (`< instance >.densify.com`) |
| `container-optimization-data-forwarder.`<br/>`config.clusters[0].name`           | :white_check_mark: | Cluster name (unique customer-wide)                    |
| `prometheus.server.namespaces`                                                   |                    | Namespaces of optional exporters (e.g. NVIDIA DCGM)    |

## Limitations

* Supported Architecture: AMD64
* Supported OS: Linux

## Documentation

* [Kubex](https://kubex.ai/)

## License

Apache 2 Licensed. See [LICENSE](LICENSE) for full details.
