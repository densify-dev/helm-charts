# Kubex Collection Stack Helm Chart for OpenShift Clusters

<picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://kubex.ai/wp-content/uploads/kubex-logo-reverse-landscape.svg">
    <source media="(prefers-color-scheme: light)" srcset="https://kubex.ai/wp-content/uploads/kubex-logo-landscape.svg">
    <img src="https://kubex.ai/wp-content/uploads/kubex-logo-landscape.svg" width="300">
</picture>

## Introduction

Kubex analyses Kubernetes clusters and produces recommendations for rightsizing resources to mitigate risk and reduce waste. 

OpenShift clusters have restrictions which do not allow the usage of the general-purpose [Kubex automation stack helm chart](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack). This chart replaces it.

This chart requires very minimal configuration in order to install the entire stack. All of it is in `values-edit.yaml`.

## Prerequisites

1. OpenShift cluster
2. Environment with the following:
   - `kubectl`
   - `helm`

3. User workload monitoring must be enabled in your OpenShift cluster to allow ephemeral storage data collection.

Update the `cluster-monitoring-config` configmap as follows:

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

> **Note:** If the `cluster-monitoring-config` configmap does not exist, you can create it with:
> ```shell
> kubectl -n openshift-monitoring create configmap cluster-monitoring-config --from-literal=config.yaml='enableUserWorkload: true'
> ```


For more information, refer to the [RedHat documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.8/html/monitoring/enabling-monitoring-for-user-defined-projects).

## Installation

The installation on an OpenShift cluster is straight-forward.

### Steps

To deploy the Kubex stack, follow these steps below:

1. Download [values-edit.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-collection-openshift/values-edit.yaml).

2. Edit `values-edit.yaml` with the relevant mandatory parameters as described in [Configuration](#configuration) and save it.

3. To add the helm repos, run:

```shell
helm repo add kubex https://densify-dev.github.io/helm-charts
helm repo update
```


4. To install the chart, run:

```shell
helm upgrade --install -n kubex --create-namespace -f values-edit.yaml kubex kubex/kubex-collection-openshift
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
| `k8s-ephemeral-storage-metrics.enabled`                                          |                    | Enable ephemeral storage metrics collection (default: `false`) |
| `node-labeler.enabled`                                                           |                    | Enable optional node-labeler subchart (`false` by default) |

## Limitations

* Supported architectures: amd64 (x64), arm64
* Release name: the helm chart release name **must** be set to `kubex` to ensure interdependencies are met

## Further Details

This chart consists of the following subcharts:

* [Kubex Data Collector](../container-optimization-data-forwarder) - Collects data and forwards it to a Kubex instance for analysis
* [k8s-ephemeral-storage-metrics](https://github.com/jmcgrath207/k8s-ephemeral-storage-metrics) - Collects ephemeral storage metrics for containers using CRI-O runtime
* [Node Labeler](../node-labeler) - Optional and disabled by default; set `node-labeler.enabled=true` to install

## Documentation

* [Kubex](https://www.docs.kubex.ai)

## License

Apache 2 Licensed. See [LICENSE](LICENSE) for full details.
