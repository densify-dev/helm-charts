# Custom Container Metrics - CPU and Memory

## Introduction

Kubex Data Collector added in version [v4.7.3-beta2](https://hub.docker.com/layers/densify/container-optimization-data-forwarder/4.7.3-beta2) optional collection of custom metrics for CPU and memory.

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

Kubex Data Collector collects data from a **single Prometheus instance**, which is configured using the `prometheus-community/prometheus` subchart.
 
There are two alternative options to provide the custom metrics to Kubex' Prometheus:

1. A "dedicated" Prometheus exporter which provides the custom metrics as described above
2. A "3rd-party" Prometheus exporter providing its "base" metrics (e.g. a _message queue exporter providing message queue metrics_) and **Prometheus recording rules** which compute the custom metrics using PromQL queries and formulas based on these "base" metrics

## Dedicated Custom Exporter

To add a dedicated custom exporter, one needs to add a Prometheus scrape config for this exporter. This scrape config assumes the exporter is exposed using k8s endpointslice and that it provides the required labels for the container metrics. For Prometheus sizing optimization, note that it is limited only to this specific endpointslice and only to the required custom metrics.

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

## 3rd-party Exporter + Recording Rules

Here we need to add both the "base" exporter scrape config and the recording rules. We assume here that the base exporter is exposed using k8s endpointslice and that it provides the required labels for the container metrics. For Prometheus sizing optimization, note that it is limited only to this specific endpointslice and only to the required base metrics.

Note that the recording rules group interval has to match cadvisor's scrape interval (as the custom metrics are an alternative to cadvisor metrics). For Openshift clusters, cadvisor's scrape interval is 1m; for all other clusters, this chart sets the scrape interval to 20s.

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
          interval: <match cadvisor scrape interval> # 1m for Openshift clusters, 20s for non-Openshift
          rules:
            - record: custom_container_cpu_sizing_seconds_total
              expr: '<PromQL expression to compute custom CPU from base metrics>'
            - record: custom_container_memory_sizing_bytes
              expr: '<PromQL expression to compute custom memory from base metrics>'
```

Edit this, save as `3rd-party-exporter.yaml` and run `helm upgrade -n kubex --reuse-values -f 3rd-party-exporter.yaml kubex kubex/kubex-automation-stack`.
