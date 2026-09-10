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

   User workload monitoring must be enabled in your OpenShift cluster to allow ephemeral storage and/or custom metrics data collection.

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
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add kubex https://densify-dev.github.io/helm-charts
helm repo update
```

If the automation engine is enabled, install or upgrade the required CRDs before installing or upgrading this stack:

```shell
helm upgrade --install kubex-crds kubex/kubex-crds \
  --namespace kubex \
  --create-namespace
```

The `kubex-crds` chart must be installed before the stack creates automation-engine resources.

6. If your cluster is not OpenShift, run this command:

```shell
helm install --create-namespace -n kubex -f values-edit.yaml -f <sizing file> kubex kubex/kubex-automation-stack
```

7. If your cluster is OpenShift, run this command:

```shell
helm install --create-namespace -n kubex -f values-edit.yaml -f <sizing file> -f https://raw.githubusercontent.com/densify-dev/helm-charts/master/charts/kubex-automation-stack/values-openshift.yaml kubex kubex/kubex-automation-stack
```

To override any OpenShift defaults, add another values file or `--set` options after the OpenShift overlay.

## Upgrading from 1.0.11 to 1.0.12

Version 1.0.12 moves the bundled Prometheus jobs from `prometheus.serverFiles.prometheus.yml.scrape_configs` to `prometheus.scrapeConfigs`. If the old values are reused during upgrade, Prometheus can receive both copies and fail because of duplicate scrape job names.

When upgrading from `1.0.11`, add the upgrade overlay at the end:

```shell
helm upgrade -n kubex --reuse-values -f https://raw.githubusercontent.com/densify-dev/helm-charts/master/charts/kubex-automation-stack/values-upgrade-1.0.11-to-1.0.12.yaml kubex kubex/kubex-automation-stack
```

## Sizing

The following table indicates - depending on the cluster size - which sizing file to use initially. Please note that these are initial sizing settings, once Kubex is running long enough and producing rightsizing recommendations for the stack components, these recommendations should be implemented for optimization.

| Cluster Size    | No. of Containers | Sizing File to Use |
| --------------- | ----------------- | ------------------ |
| Extra Small     | 0-500             | [values-xsmall.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/values-xsmall.yaml) |
| Small           | 500-5000          | [values-small.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/values-small.yaml) |
| Medium          | 5001-10000        | [values-medium.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/values-medium.yaml) |
| Large           | 10001+            | [values-large.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/values-large.yaml) |


## Custom Metrics (Optional)

Kubex Data Collector can optionally collect custom container CPU and memory metrics. For details see [docs/custom-metrics.md](docs/custom-metrics.md).

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
| `gpu-process-exporter.enabled`                                                           |                    | Enable GPU process exporter subchart (default: `true`) |
| `beyla.enabled`                                                           |                    | Enable Grafana Beyla for application runtime detection (default: `true`) |
| `k8s-ephemeral-storage-metrics.enabled`                                          |                    | Enable ephemeral storage metrics collection (default: `true`) |
| `node-labeler.enabled`                                                           |                    | Enable optional node-labeler subchart to add Kubex Node Group labels to nodes; useful when nodes lack standard cloud provider node pool/group labels (default: `false`) |
| `kubex-connector.enabled`                                                        |                    | Enable connector subchart (default: `true`) |
| `kubex-ai-cdi.enabled`                                                           |                    | Enable kubex-ai-cdi subchart (default: `true`) |
| `kubex-automation-engine.enabled`                                                |                    | Enable optional automation engine subchart for automated workload rightsizing (default: `false`) |
| `kubex-automation-engine.kubex.clusterNameFrom`                                  |                    | Defaults to `configMapKeyRef` on `kubex-stack-runtime/kubex_cluster_name` |
| `kubex-automation-engine.gateway.configSecretName`                               |                    | Defaults to `densify-api-secret` created by the stack |
| `kubex-connector.heartbeatSeconds`                                               |                    | Connector heartbeat interval in seconds |
| `kubex-connector.requestTimeoutSeconds`                                          |                    | Connector request timeout in seconds |

Connector, CDI, and Automation Engine use the shared Kubex host and cluster entered under `container-optimization-data-forwarder.config.*`. The stack publishes those runtime values in `kubex-stack-runtime`: the connector reads all connection identity from it, CDI reads the cluster name from it, and the automation engine sources `CLUSTER_NAME` from it. Credentials come from `stack.densify` through `densify-api-secret`, which the connector consumes through `forwarderCredentialsSecretRef.name` by default, and the automation engine consumes through `gateway.configSecretName`. The stack chart also owns the CDI service account and RBAC by rendering those manifests itself while disabling `kubex-ai-cdi.rbac.enabled` in the subchart. Component resources are selected by the `values-xsmall.yaml`, `values-small.yaml`, `values-medium.yaml`, and `values-large.yaml` overlays.

For the full stack RBAC shape and defaults, refer to `charts/kubex-automation-stack/values.yaml`.

For a guided explanation of the stack-managed CDI RBAC model, see [docs/RBAC-Guide.md](docs/RBAC-Guide.md).

## Enabling Kubex Automation Engine

> **Runtime defaults (1.1.0):** the stack-managed runtime ConfigMap is
> `kubex-stack-runtime`. Default stack installs are updated automatically because
> the stack also updates the connector, CDI, and automation-engine subchart
> wiring. If you explicitly override `kubex-connector.forwarderConfigMap.name`
> or `kubex-ai-cdi.worker.clusterNameConfigMap.name`, update those overrides to
> `kubex-stack-runtime`.

The Kubex Automation Engine provides automated workload rightsizing based on Kubex recommendations. It is disabled by default to support backward compatibility with customers who may have previously installed it separately.

### For New Installations

The automation engine reuses the stack-managed `densify-api-secret` and `kubex-stack-runtime` ConfigMap that are populated from the forwarder configuration, so no additional cluster name or Kubex host values are required. Simply uncomment the automation-engine section in your `values-edit.yaml`:

```yaml
container-optimization-data-forwarder:
  config:
    forwarder:
      densify:
        url:
          host: 'customer.kubex.ai'
    clusters:
      - name: 'my-cluster'

# Then enable automation engine (uncomment these lines):
kubex-automation-engine:
  enabled: true
```

Then install normally:

```shell
helm install --create-namespace -n kubex \
  -f values-edit.yaml \
  -f <sizing file> \
  kubex kubex/kubex-automation-stack
```

Alternatively, enable via command line:

```shell
helm install --create-namespace -n kubex \
  -f values-edit.yaml \
  -f <sizing file> \
  --set kubex-automation-engine.enabled=true \
  kubex kubex/kubex-automation-stack
```

### For Existing Installations

For customers who previously installed kubex-automation-engine separately, you can continue to use the standalone installation without changes. To migrate to the stack-integrated version:

1. Uninstall the standalone kubex-automation-engine
2. Install or upgrade the `kubex-crds` chart
3. Upgrade the kubex-automation-stack with the automation engine enabled

### Using a Pre-Created Kubex API Secret

By default, the stack creates a shared `densify-api-secret` from `stack.densify.username` and `stack.densify.encrypted_password`.

To use a Secret managed outside of this chart, set:

```yaml
stack:
  densify:
    createSecret: false
```

When `createSecret: false` is set, the stack does not create `densify-api-secret`. You must either pre-create a Secret with that name in the release namespace, or override each component to use a different existing Secret.

The default stack wiring expects these Secret references:

```yaml
container-optimization-data-forwarder:
  config:
    forwarder:
      densify:
        url:
          UserSecretName: densify-api-secret

kubex-connector:
  forwarderCredentialsSecretRef:
    name: densify-api-secret

kubex-automation-engine:
  gateway:
    configSecretName: densify-api-secret
```

The Secret must contain these keys:

| Key | Required By |
| --- | --- |
| `username` | data collection, connector, automation engine |
| `epassword` | data collection, connector, automation engine |
| `url` | automation engine |
| `DENSIFY_BASE_URL` | automation engine |

Example:

```shell
kubectl -n kubex create secret generic densify-api-secret \
  --from-literal=username='<username>' \
  --from-literal=epassword='<encrypted-password>' \
  --from-literal=url='<instance>.kubex.ai' \
  --from-literal=DENSIFY_BASE_URL='https://<instance>.kubex.ai'
```

### Configuration

The automation engine automatically shares configuration with other stack components:
- **Credentials**: Uses the same `densify-api-secret` created by the stack (contains username, epassword, url, and DENSIFY_BASE_URL)
- **Cluster Name**: Uses `kubex-automation-engine.kubex.clusterNameFrom`, which defaults to `kubex-stack-runtime/kubex_cluster_name`
- **Kubex Instance URL**: Uses `gateway.configSecretName`, which defaults to `densify-api-secret`

This approach ensures configuration consistency and eliminates the risk of mismatched settings between components.

For additional automation engine configuration options, refer to the [Kubex Automation Engine chart documentation](../kubex-automation-engine).

## Limitations

* Supported architectures: amd64 (x64), arm64
* Release name: the helm chart release name **must** be set to `kubex` to ensure interdependencies are met

## Further Details

This chart consists of the following subcharts:

* [Kubex Data Collector](../container-optimization-data-forwarder) - Collects data and forwards it to a Kubex instance for analysis

* [Prometheus Community Prometheus chart](https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus/) - Used on Kubernetes clusters; disabled for OpenShift installs via the OpenShift overlay values file

* [Grafana Beyla chart](https://github.com/grafana/beyla/tree/main/charts/beyla) - Used on Kubernetes clusters to get application runtime information; requires elevated permissions; disabled for OpenShift installs via the OpenShift overlay values file

* [GPU Process Exporter](../gpu-process-exporter) - Collects container-level metrics for containers using Nvidia GPUs, to overcome the limitations of Nvidia's [DCGM Exporter](https://github.com/NVIDIA/dcgm-exporter) in providing those metrics for use-cases like GPU sharing strategies (e.g. time-slicing, MPS) or the [KAI scheduler](https://github.com/kai-scheduler/KAI-Scheduler); enabled by default and runs **only** on nodes with Nvidia GPUs; requires read-only access to the node and elevated permissions; disabled for OpenShift installs via the OpenShift overlay values file

* [k8s-ephemeral-storage-metrics](../k8s-ephemeral-storage-metrics) - Collects ephemeral storage metrics for containers.

* [Node Labeler](../node-labeler) - Adds labels to nodes to indicate which Kubex Node Group they belong to. This is an optional component (disabled by default) that should be enabled when:
  - Nodes lack standard cloud provider node pool/group labels (e.g., GKE node pools, EKS node groups, AKS agent pools)
  - Additional Kubex-specific grouping labels are needed beyond cloud provider labels
  - Enhanced node group visibility is desired in OpenShift environments (leverages Machine API)

* [Kubex Connector](../kubex-connector) - In-cluster connector used for the cluster data interface.

* [kubex-ai-cdi](../kubex-ai-cdi) - In-cluster Kubex cluster data interface service.

* [Kubex Automation Engine](../kubex-automation-engine) - Optional automated workload rightsizing engine that applies Kubex recommendations to optimize resource allocation. Disabled by default. Can be enabled for new installations as part of the stack or installed separately for backward compatibility with existing deployments.

## Documentation

* [Kubex](https://docs.kubex.ai)

## License

Apache 2 Licensed. See [LICENSE](LICENSE) for full details.
