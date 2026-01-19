# Kubex Collection Stack Helm Chart

<picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://www.kubex.ai/wp-content/uploads/kubex-by-densify-logo-reverse.png">
    <source media="(prefers-color-scheme: light)" srcset="https://www.kubex.ai/wp-content/uploads/kubex-by-densify-logo.png">
    <img src="https://www.kubex.ai/wp-content/uploads/kubex-by-densify-logo.png" width="300">
</picture>

## Introduction

Kubex analyses Kubernetes clusters and produces recommendations for rightsizing resources to mitigate risk and reduce waste. This chart includes all components required for the Kubex Data Collector, optimization recommendations, and optional automated resource optimization.

This chart requires very minimal configuration in order to install the entire stack. All of it is in `values-edit.yaml`.

## Installation

To deploy the Kubex Collection Stack, follow these steps below:

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
helm install --create-namespace -n kubex -f values-edit.yaml -f <sizing file> kubex densify/kubex-automation-stack
```

7. If your cluster has arm64 architecture, run this command:

```shell
helm install --create-namespace -n kubex -f values-edit.yaml -f <sizing file> -f values-arm64.yaml kubex densify/kubex-automation-stack
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

### Global Configuration

| Parameter                                                | Mandatory          | Description                                            |
| -------------------------------------------------------- | ------------------ | ------------------------------------------------------ |
| `global.cluster.name`                                    | :white_check_mark: | Cluster name **(must be unique, customer-wide)**      |
| `global.kubex.url.host`                                  | :white_check_mark: | Kubex instance hostname (e.g., `<instance>.kubex.ai` or `<instance>.densify.com`) |
| `global.createSecret`                                    |                    | Set to `false` if providing your own secret (default: `true`) |

### Kubex Data Collector

| Parameter                                                | Mandatory          | Description                                            |
| -------------------------------------------------------- | ------------------ | ------------------------------------------------------ |
| `kubex-data-collector.enabled`                          |                    | Enable Kubex Data Collector (default: `true`) |
| `kubex-data-collector.credentials.username`             | :white_check_mark: | Kubex user account for Kubex Data Collector                 |
| `kubex-data-collector.credentials.epassword`            | :white_check_mark: | Encrypted password for Kubex Data Collector user            |
| `kubex-data-collector.`<br/>`cronJob.successfulJobsHistoryLimit` |                    | Number of successful jobs to keep |
| `kubex-data-collector.`<br/>`cronJob.failedJobsHistoryLimit` |                    | Number of failed jobs to keep |
| `kubex-data-collector.`<br/>`cronJob.ttlSecondsAfterFinished` |                    | TTL to keep jobs after completion/failure |
| `kubex-data-collector.`<br/>`cronJob.backoffLimit` |                    | Backoff limit for jobs |

### Kubex Automation Controller (Optional)

**Note:** The automation controller uses separate credentials that can be the same or different from the Kubex Data Collector credentials.

#### Basic Configuration (in values-edit.yaml)

| Parameter                                                        | Mandatory          | Description                                            |
| ---------------------------------------------------------------- | ------------------ | ------------------------------------------------------ |
| `kubex-automation-controller.enabled`                            |                    | Enable automated resource optimization (default: `false`) |
| `kubex-automation-controller.createSecrets`                      |                    | Create secrets for Kubex API and Valkey (default: `true`) |
| `kubex-automation-controller.credentials.username`               | :white_check_mark: (if enabled) | Kubex API username for automation **(can be different from Kubex Data Collector user)** |
| `kubex-automation-controller.credentials.epassword`              | :white_check_mark: (if enabled) | Kubex API encrypted password for automation |
| `kubex-automation-controller.valkey.credentials.password`        | :white_check_mark: (if enabled) | Password for Valkey authentication    |

#### Advanced Automation Configuration (Optional)

For advanced automation settings (policies, scopes, Valkey tuning, resource limits), download and customize [kubex-automation-values.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/kubex-automation-values.yaml):

1. Download the file: `wget https://raw.githubusercontent.com/densify-dev/helm-charts/master/charts/kubex-automation-stack/kubex-automation-values.yaml`
2. Edit settings as needed (see inline comments for guidance)
3. Install with: `helm install -n kubex -f values-edit.yaml -f kubex-automation-values.yaml -f <sizing-file> kubex densify/kubex-automation-stack`

**Important Notes:**
- When `policy.automationEnabled: true`, you **must** define at least one scope in `kubex-automation-values.yaml`
- Default policy (`base-optimization`) is included - customize only if needed
- Without `kubex-automation-values.yaml`, automation uses conservative defaults with `automationEnabled: false`

### Prometheus Configuration

| Parameter                                                        | Mandatory          | Description                                            |
| ---------------------------------------------------------------- | ------------------ | ------------------------------------------------------ |
| `prometheus.server.persistentVolume.`<br/>`storageClass`         |                    | Storage class for Prometheus persistent volume |

## Limitations

* Supported architectures: amd64 (x64), arm64
* Release name: the helm chart release name **must** be set to `kubex` to ensure interdependencies are met

## Further Details

This chart consists of three subcharts:

* [Kubex Automation Controller](../kubex-automation-controller) (optional), which automates the application of optimization recommendations to running containers

* [Kubex Data Collector](../container-optimization-data-forwarder) (aliased as `kubex-data-collector`), which collects and sends metrics to a Kubex instance for analysis

* [Prometheus Community Prometheus chart](https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus/) which contains the entire stack required for the Kubex Data Collector

### Configuration Structure

**Global values** (`global.cluster.name` and `global.kubex.url.host`) are automatically shared across all subcharts. This simplifies configuration when multiple components are enabled.

**Credentials:** The stack uses two separate sets of credentials:
1. **Kubex Data Collector Credentials** (`kubex-data-collector.credentials.*`) - Used by the Kubex Data Collector to send metrics to Kubex
2. **Automation Credentials** (`kubex-automation-controller.credentials.*`) - Used by the automation controller to apply optimization recommendations

These credentials **can be the same or different** depending on your security requirements.

**kubex-automation-controller:** Always uses global values for cluster name and URL when enabled. No subchart-specific overrides are supported for these settings.

## Documentation

* [Kubex](https://www.kubex.ai)

## License

Apache 2 Licensed. See [LICENSE](LICENSE) for full details.
