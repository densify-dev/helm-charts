# App-Specific Metrics

When the bundled Prometheus is enabled, the chart can discover supported application metric exporters from Kubernetes Service or Pod labels. Configure selectors under `prometheus.appScrapeConfigs` in your custom values file. On OpenShift, where the bundled Prometheus is disabled, these values have no effect; configure user workload monitoring with a `ServiceMonitor` instead.

## Supported Exporters

The current supported app-specific exporters are:

| App | Exporters |
| --- | --- |
| `jvm` | [OpenTelemetry Java Agent](https://opentelemetry.io/docs/zero-code/java/agent/) configured to expose a Prometheus exporter endpoint, and [JMX Exporter](https://github.com/prometheus/jmx_exporter) v1.x |
| `vllm` | [vLLM Prometheus metrics exporters](https://docs.vllm.ai/en/stable/design/metrics/) |

For JVM applications, configure the OpenTelemetry Java Agent so Prometheus pulls metrics from its exporter endpoint (e.g. by using the environment variables `OTEL_METRICS_EXPORTER=prometheus`, `OTEL_EXPORTER_PROMETHEUS_HOST=0.0.0.0`, `OTEL_EXPORTER_PROMETHEUS_PORT=...`). Sending metrics by the usual OpenTelemetry push mechanism is not supported by this scrape configuration.
JMX Exporter must be v1.x; v0.x is not supported. Its rules must emit metric names accepted by the regex in `prometheus.appMetricNames.jvm`.

## Metric Filtering

The chart keeps only metric names matching the app's regex in `values.yaml`:

```yaml
prometheus:
  appMetricNames:
    jvm: '^(target_info|jvm_((buffer_(memory|pool)_used|memory_(init|limit|max|used(_after_last_gc)?))_bytes|gc_(collection|duration)_seconds_.*|runtime_info|thread_count|threads_current))$'
    vllm: '^vllm:(e2e_request_latency|time_to_first_token)_seconds.*$'
```

Configure JMX Exporter v1.x rules to produce names matching the JVM regex; other metrics are dropped.

## Selector Format

Each app has two optional selector maps:

```yaml
prometheus:
  appScrapeConfigs:
    jvm:
      serviceLabels: {}
      podLabels: {}
    vllm:
      serviceLabels: {}
      podLabels: {}
```

Each map key is a **Kubernetes label name**. Each value is a Prometheus RE2 regular expression matched against that label's value. Quote regular expressions in YAML. Use `'*'` to match any present value.

When a map contains multiple labels, a target must match every label. An empty map disables that discovery method for the app.

Choose either `serviceLabels` or `podLabels` for each app. Configuring both is not recommended because it creates two discovery jobs and can make target ownership and troubleshooting less clear. When both are configured, endpoint targets whose Pods match `podLabels` are dropped from EndpointSlice discovery to avoid double scraping. If a Service exposes the metrics port but its Pod does not declare the corresponding `containerPort`, the replacement Pod target is unavailable and metrics can be lost.

## Discover by Service Labels

Use `serviceLabels` when Services reliably identify app metric endpoint slices:

```yaml
prometheus:
  appScrapeConfigs:
    jvm:
      serviceLabels:
        example.com/team: '*'
        example.com/application-runtime: 'jvm'
      podLabels: {}
    vllm:
      serviceLabels: {}
      podLabels: {}
```

This creates the `kubex-jvm-endpoint` scrape job using Kubernetes EndpointSlice discovery. Declare the exporter metrics port in the Service spec; never edit controller-managed EndpointSlice resources. EndpointSlice discovery attempts HTTP `/metrics` against every discovered Service port and may also discover additional Pod container ports. Prefer a dedicated metrics Service and dedicated ports where feasible.

In this example, only Services containing **both labels with matching values** are kept.

## Discover by Pod Labels

Use `podLabels` when exporter Pods have stable identifying labels:

```yaml
prometheus:
  appScrapeConfigs:
    jvm:
      serviceLabels: {}
      podLabels: {}
    vllm:
      serviceLabels: {}
      podLabels:
        app.kubernetes.io/name: 'vllm'
```

This creates the `kubex-vllm-pod` scrape job using Kubernetes Pod discovery. Declare the exporter metrics port as a `containerPort` in the Pod spec. Every declared container port becomes a target; the job does not select by port name or number, so other ports may receive unsuccessful HTTP `/metrics` scrapes.


## Apply Configuration

Add selectors to the values file used for the Kubex release, then upgrade:

```shell
helm upgrade --install --reset-then-reuse-values \
  -f values-edit.yaml \
  -n kubex \
  kubex kubex/kubex-automation-stack
```

The chart filters scraped samples to metric names supported for each app and populates `namespace`, `pod`, `container`, and `node` target labels only when corresponding Kubernetes discovery metadata exists. Non-Pod EndpointSlice targets may lack `pod`, `container`, and `node`.

Any override of `prometheus.extraScrapeConfigs` replaces the chart's generator. Leave the chart default intact unless the override explicitly preserves `{{ include "kubex-automation-stack.appScrapeConfigs" . }}`.
