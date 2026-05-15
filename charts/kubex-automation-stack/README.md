# Kubex Collection Stack Helm Chart

<picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://kubex.ai/wp-content/uploads/kubex-logo-reverse-landscape.svg">
    <source media="(prefers-color-scheme: light)" srcset="https://kubex.ai/wp-content/uploads/kubex-logo-landscape.svg">
    <img src="https://kubex.ai/wp-content/uploads/kubex-logo-landscape.svg" width="300">
</picture>

## Introduction

Kubex analyses Kubernetes clusters and produces recommendations for rightsizing resources to mitigate risk and reduce waste. This chart includes all components required for that.

This chart supports both Kubernetes clusters and OpenShift clusters.

This chart requires very minimal configuration in order to install the entire stack. All required user-specific configuration is in `values-edit.yaml`.

## Installation

To deploy the Kubex Collection Stack, follow these steps below:

1. Determine your sizing file as described in [Sizing](#sizing) and download it.

2. Download [values-edit.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/values-edit.yaml).

3. If deploying on OpenShift, use the OpenShift overlay file: [values-openshift.yaml](https://raw.githubusercontent.com/densify-dev/helm-charts/master/charts/kubex-automation-stack/values-openshift.yaml).

   User workload monitoring must be enabled in your OpenShift cluster to allow ephemeral storage data collection.

   Update the `cluster-monitoring-config` ConfigMap:

   ```shell
   kubectl -n openshift-monitoring edit configmap cluster-monitoring-config
   ```

   Ensure the config contains:

   ```yaml
   apiVersion: v1
   data:
     config.yaml: |
       enableUserWorkload: true
   kind: ConfigMap
   ```

   If the `cluster-monitoring-config` ConfigMap does not exist, create it with:

   ```shell
   kubectl -n openshift-monitoring create configmap cluster-monitoring-config --from-literal=config.yaml='enableUserWorkload: true'
   ```

4. Edit `values-edit.yaml` with the relevant mandatory parameters as described in [Configuration](#configuration).

5. To add the helm repos, run:

```shell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add kubex https://densify-dev.github.io/helm-charts
helm repo update
```

6. If your cluster is not OpenShift, run this command:

```shell
helm install --create-namespace -n kubex -f values-edit.yaml -f <sizing file> kubex kubex/kubex-automation-stack
```

7. If your cluster is OpenShift, run this command:

```shell
helm install --create-namespace -n kubex -f values-edit.yaml -f <sizing file> -f https://raw.githubusercontent.com/densify-dev/helm-charts/master/charts/kubex-automation-stack/values-openshift.yaml kubex kubex/kubex-automation-stack
```

To override any OpenShift defaults, add another values file or `--set` options after the OpenShift overlay.

## Sizing

The following table indicates - depending on the cluster size - which sizing file to use initially. Please note that these are initial sizing settings, once Kubex is running long enough and producing rightsizing recommendations for the stack components, these recommendations should be implemented for optimization.

| Cluster Size    | No. of Containers | Sizing File to Use |
| --------------- | ----------------- | ------------------ |
| Extra Small     | 0-500             | [values-xsmall.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/values-xsmall.yaml) |
| Small           | 500-5000          | [values-small.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/values-small.yaml) |
| Medium          | 5001-10000        | [values-medium.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/values-medium.yaml) |
| Large           | 10001+            | [values-large.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/values-large.yaml) |

## Configuration

The following table lists configuration parameters in `values-edit.yaml`.

| Parameter                                                                        | Mandatory          | Description                                            |
| -------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------ |
| `stack.densify.username`                                                         | :white_check_mark: | Kubex user account                                   |
| `stack.densify.encrypted_password`                                               | :white_check_mark: | Encrypted password for the Kubex User                |
| `openshift.enabled`                                                              |                    | Enables OpenShift-specific templates and validations |
| `stack.prometheus.deploy`                                                        |                    | Deploy the bundled Prometheus chart (`true` by default, `false` on OpenShift) |
| `container-optimization-data-forwarder.`<br/>`config.forwarder.densify.url.host` | :white_check_mark: | Kubex instance hostname (`< instance >.kubex.ai`) |
| `container-optimization-data-forwarder.`<br/>`config.clusters[0].name`           | :white_check_mark: | Cluster name **(must be unique, customer-wide; if not, specify an alternate name)** |
| `container-optimization-data-forwarder.`<br/>`cronJob.successfulJobsHistoryLimit` |                    | Number of successful jobs to keep |
| `container-optimization-data-forwarder.`<br/>`cronJob.failedJobsHistoryLimit` |                    | Number of failed jobs to keep |
| `container-optimization-data-forwarder.`<br/>`cronJob.ttlSecondsAfterFinished` |                    | TTL to keep jobs after completion/failure |
| `container-optimization-data-forwarder.`<br/>`cronJob.backoffLimit` |                    | Backoff limit for jobs |
| `prometheus.server.persistentVolume.`<br/>`storageClass`                         |                    | Storage class for Prometheus persistent volume |
| `k8s-ephemeral-storage-metrics.enabled`                                          |                    | Enable ephemeral storage metrics collection (default: `true`) |
| `node-labeler.enabled`                                                           |                    | Enable optional node-labeler subchart (`false` by default) |

## Limitations

* Supported architectures: amd64 (x64), arm64
* Release name: the helm chart release name **must** be set to `kubex` to ensure interdependencies are met

## Further Details

This chart consists of the following subcharts:

* [Kubex Data Collector](../container-optimization-data-forwarder) - Collects data and forwards it to a Kubex instance for analysis

* [Prometheus Community Prometheus chart](https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus/) - Used on Kubernetes clusters; disabled for OpenShift installs via the OpenShift overlay values file

* [k8s-ephemeral-storage-metrics](https://github.com/jmcgrath207/k8s-ephemeral-storage-metrics) - Collects ephemeral storage metrics for containers. This is currently disabled by default as the feature is in BETA.

* [Node Labeler](../node-labeler) - Adds labels to nodes to indicate which Kubex Node Group they belong to. This is an optional component that can be enabled if desired (disabled by default).

## Documentation

* [Kubex](https://www.docs.kubex.ai)

## License

Apache 2 Licensed. See [LICENSE](LICENSE) for full details.
