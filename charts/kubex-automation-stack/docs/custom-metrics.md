# Custom Container Metrics - CPU and Memory

## Introduction

Starting with version [v4.7.3-beta2](https://hub.docker.com/layers/densify/container-optimization-data-forwarder/4.7.3-beta2), Kubex Data Collector can optionally collect custom CPU and memory metrics.

The motivation behind this feature is to allow users to provide for **specific workloads** other metrics to drive the sizing recommendations - alternative to the standard cadvisor metrics which are typically used for that. One example use-case is of message queue consumers, where the memory should be driven by a formula based on queue depth, average message size etc.

## Custom Metrics Description

### CPU

#### Name

`custom_container_cpu_sizing_seconds_total`

#### cadvisor equivalent metrics

- `container_cpu_usage_seconds_total`

#### Semantics

Total CPU usage in seconds.

#### Required labels

- `namespace`
- `pod`
- `container`
- `node`

### Memory

#### Name

`custom_container_memory_sizing_bytes`

#### cadvisor equivalent metrics

- `container_memory_usage_bytes`
- `container_memory_rss`
- `container_memory_working_set_bytes`

#### Semantics

Memory usage in bytes.

#### Required labels

- `namespace`
- `pod`
- `container`
- `node`

## Inclusion in this Helm chart

Kubex Data Collector collects data from a **single Prometheus endpoint**. On non-OpenShift clusters, this endpoint is provided by the `prometheus-community/prometheus` subchart. On OpenShift clusters, the bundled Prometheus is disabled and the collector queries the OpenShift Thanos Querier, which includes metrics from user workload monitoring.
 
There are two alternative options to provide the custom metrics to Kubex' Prometheus:

1. A "dedicated" Prometheus exporter which provides the custom metrics as described above
2. A "3rd-party" Prometheus exporter providing its "base" metrics (e.g. a _message queue exporter providing message queue metrics_) and **Prometheus recording rules** which compute the custom metrics using PromQL queries and formulas based on these "base" metrics

## Dedicated Custom Exporter

### Non-OpenShift clusters

To add a dedicated custom exporter to a non-OpenShift cluster, one needs to add a Prometheus scrape config for this exporter. This scrape config assumes the exporter is exposed using k8s endpointslice and that it provides the required labels for the container metrics. For Prometheus sizing optimization, note that it is limited only to this specific endpointslice and only to the required custom metrics.

```yaml
prometheus:
  scrapeConfigs:
    kubernetes-service-endpoints-custom:
      enabled: true
      job_name: ""
      honor_labels: true
      kubernetes_sd_configs:
        - role: endpointslice
      relabel_configs:
        - source_labels: [__meta_kubernetes_endpointslice_name]
          regex: '<regex matching the endpointslice name>'
          action: keep
      metric_relabel_configs:
        - source_labels: [__name__]
          regex: '^custom_container_(cpu_sizing_seconds_total|memory_sizing_bytes)$'
          action: keep
```

Edit this, save as `dedicated-exporter.yaml` and run `helm upgrade -n kubex --reuse-values -f dedicated-exporter.yaml kubex kubex/kubex-automation-stack`.

### OpenShift clusters

OpenShift uses user workload monitoring instead of the Prometheus subchart. Ensure that user workload monitoring is [enabled](README.md#installation), then create a `ServiceMonitor` in the same user-defined namespace as the exporter's `Service`. The `Service` must have the labels selected by `matchLabels` and a named metrics port matching `port` below.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: custom-metrics-exporter
  namespace: <exporter namespace>
spec:
  endpoints:
    - interval: 1m
      path: /metrics
      port: metrics
      scheme: http
      metricRelabelings:
        - sourceLabels: [__name__]
          regex: '^custom_container_(cpu_sizing_seconds_total|memory_sizing_bytes)$'
          action: keep
  selector:
    matchLabels:
      app: <exporter Service label value>
```

Edit this, save it as `dedicated-exporter-servicemonitor.yaml`, and run `oc apply -f dedicated-exporter-servicemonitor.yaml`.

## 3rd-party Exporter + Recording Rules

Here we need to add both the "base" (3rd-party) exporter and the recording rules. Note that the recording rules group interval has to match cadvisor's scrape interval (as the custom metrics are an alternative to cadvisor metrics). For OpenShift clusters, cadvisor's scrape interval is 1m; for all other clusters, this chart sets the scrape interval to 20s.

### Non-OpenShift clusters

We assume here that the base exporter is exposed using k8s endpointslice and that it provides the required labels for the container metrics. For Prometheus sizing optimization, note that it is limited only to this specific endpointslice and only to the required base metrics.

```yaml
prometheus:
  scrapeConfigs:
    kubernetes-service-endpoints-base:
      enabled: true
      job_name: ""
      honor_labels: true
      kubernetes_sd_configs:
        - role: endpointslice
      relabel_configs:
        - source_labels: [__meta_kubernetes_endpointslice_name]
          regex: '<regex matching the endpointslice name>'
          action: keep
      metric_relabel_configs:
        - source_labels: [__name__]
          regex: '<regex matching ONLY the required "base" metrics used in the recording rules>'
          action: keep
  serverFiles:
    rules:
      groups:
        - name: custom-metrics.rules
          interval: 20s
          rules:
            - record: custom_container_cpu_sizing_seconds_total
              expr: '<PromQL expression to compute custom CPU from base metrics>'
            - record: custom_container_memory_sizing_bytes
              expr: '<PromQL expression to compute custom memory from base metrics>'
```

Edit this, save as `3rd-party-exporter.yaml` and run `helm upgrade -n kubex --reuse-values -f 3rd-party-exporter.yaml kubex kubex/kubex-automation-stack`.

### OpenShift clusters

OpenShift user workload monitoring needs two resources in the same user-defined namespace as the base exporter's `Service`:

1. A `ServiceMonitor` to scrape only the base metrics used by the formulas
2. A `PrometheusRule` containing the recording rules

Do not add the rules to the chart's `prometheus.serverFiles` or modify the OpenShift monitoring stack. By default, OpenShift's user workload Thanos Ruler selects the `PrometheusRule`, evaluates it against metrics available through Thanos Querier, and exposes the recorded series through that same query endpoint. This is the endpoint used by Kubex Data Collector.

The exporter's `Service` must have the labels selected by `matchLabels` and a named metrics port matching `port` below.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: custom-metrics-base-exporter
  namespace: <exporter namespace>
spec:
  endpoints:
    - interval: 1m
      path: /metrics
      port: metrics
      scheme: http
      metricRelabelings:
        - sourceLabels: [__name__]
          regex: '<regex matching ONLY the required "base" metrics used in the recording rules>'
          action: keep
  selector:
    matchLabels:
      app: <exporter Service label value>
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: custom-container-metrics
  namespace: <exporter namespace>
spec:
  groups:
    - name: custom-metrics.rules
      interval: 1m
      rules:
        - record: custom_container_cpu_sizing_seconds_total
          expr: '<PromQL expression to compute custom CPU from base metrics>'
        - record: custom_container_memory_sizing_bytes
          expr: '<PromQL expression to compute custom memory from base metrics>'
```

Each PromQL expression must return the required `namespace`, `pod`, `container`, and `node` labels. Edit this, save it as `3rd-party-exporter-monitoring.yaml`, and run `oc apply -f 3rd-party-exporter-monitoring.yaml`.
