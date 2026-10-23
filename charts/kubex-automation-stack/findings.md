# CVE-2026-111943 dependency and internet MITM assessment

Assessment date: October 23, 2026.

## Summary

Six direct dependencies already select patched main binaries. Three need attention: Prometheus, Beyla, and ephemeral-storage metrics.

- Prometheus has both application and chart fixes available.
- Beyla has an application fix, but its latest chart does not select it yet.
- Ephemeral-storage metrics has neither a confirmed fixed application image nor a chart selecting one.

## What constitutes a fix

[Go's advisory](https://pkg.go.dev/vuln/GO-2026-6809) specifies Go **1.26.10** or **1.27.3**. Applications must be rebuilt; changing Helm metadata alone does not fix compiled binaries.

The assessment checked `Chart.yaml`, vendored dependency archives, chart defaults, upstream releases, and published Densify image binaries' Go build metadata.

## Direct dependencies

“Internet exposure” means configured runtime traffic, not image pulls or Helm downloads. Risk descriptions concern this certificate-trust issue, not each component's overall security posture.

| Dependency | Pinned chart / actual image | Application and chart fix status | Internet HTTPS traffic and MITM exposure |
| --- | --- | --- | --- |
| **container-optimization-data-forwarder** | Chart **4.0.17**; image `:4`, currently application **4.8.1** | **Already patched at the current registry digest.** Both `dataCollection` and `forwarder` binaries use **Go 1.27.3**. No chart upgrade is needed. | **Yes.** Uploads collected data to the configured Kubex/Densify HTTPS endpoint. Optional managed-Prometheus/cloud authentication adds external endpoints. This is a **high-priority trust boundary**, but the checked image contains the fix. |
| **kubex-connector** | Chart **1.11.1**; connector **1.11.0**; relay `automation-gateway:1.9` | **Already patched.** Connector and relay both use **Go 1.27.3**. | **Yes.** By default, the connector contacts its localhost relay; the relay establishes an external **WSS** tunnel and HTTPS authentication to Kubex. WSS has the same certificate-validation concern. This is a high-impact boundary because the tunnel carries CDI requests and results. |
| **kubex-ai-cdi** | Chart/image **1.11.0** | **Already patched.** The server uses **Go 1.27.3**. | **No direct internet endpoint is configured.** Queries the Kubernetes API and optionally Prometheus. Results leave indirectly through the connector. **Low direct internet-MITM exposure**; this is not an external AI-provider client by default. |
| **kubex-automation-engine** | Chart/controller **1.16.1**; gateway **1.9** | **The main controller and gateway are already patched:** both use **Go 1.27.3**. See the helper-image caveat below. | **Yes, when enabled.** The gateway exchanges recommendations and automation data with the Kubex HTTPS API. This is a **high-impact boundary** because altered recommendations could influence workload changes. The engine is **disabled by default**. |
| **prometheus** | Chart **29.21.0**; application **3.13.2** | **The pinned version predates the fix. Both fixes are available:** application **3.13.5** or **3.15.1**; chart **29.37.1** selects **3.15.1**. Latest chart **29.37.2** also updates the reloader. | **No internet destination is configured by default.** Scrapes cluster services, API, and nodes; remote write/read defaults are empty. **Low default internet exposure**, increasing with external scrapes, remote write/read, or cloud discovery/authentication. |
| **beyla** | Chart **1.16.10**; application **3.25.0** | **An application fix is available: 3.39.1**, using patched Go. **A chart selecting the fix is not yet available:** latest chart **1.16.15** still selects **3.39.0**. An explicit image override or later chart is required. | **No internet exporter is configured here.** Survey mode exposes local Prometheus metrics. **Low default internet exposure**. External OTLP/Grafana Cloud export would introduce it. Observing applications' internet traffic does not mean Beyla initiates those connections. |
| **k8s-ephemeral-storage-metrics** | Chart **1.22.1**; actual image **1.22.0** | **Not patched; no fixed application/chart was found.** The published binary uses **Go 1.26.5**. Chart `appVersion: 1.22.1` does not match the selected image, which remains **1.22.0**. | **No internet endpoint is configured.** Queries Kubernetes API/node statistics; optionally kubelets. **Low internet-MITM exposure**, despite the vulnerable runtime. |
| **gpu-process-exporter** | Chart **1.1.5**; image **1.1.2** | **Already patched.** The exporter uses **Go 1.27.3**. | **No internet endpoint is configured.** Reads local NVIDIA/process data and Kubernetes metadata; serves metrics. **Low internet-MITM exposure**. |
| **node-labeler** | Chart **0.1.3**; image **0.0.5** | **Already patched.** The controller uses **Go 1.27.3**. | **No internet endpoint is configured.** Uses Kubernetes/OpenShift APIs. **Low internet-MITM exposure**. **Disabled by default**. |

The automation-controller/gateway fixes are also documented in [`../kubex-automation-engine/CHANGELOG.md`](../kubex-automation-engine/CHANGELOG.md), under versions 1.16.0 and 1.16.1.

### Additional Prometheus components

Updating the Prometheus server does **not** prove every bundled binary is fixed.

| Component | Current selection | Fix availability | Internet traffic |
| --- | --- | --- | --- |
| **Config reloader** | **0.93.0** | Fixed **0.94.2**, included in Prometheus chart **29.37.2**. | Local Prometheus reload endpoint; no default internet traffic. |
| **kube-state-metrics** | Chart **8.1.1**, application **2.19.1** | No fixed upstream release was found. Latest **2.20.0** reports Go **1.26.6**, still before the fix. | Kubernetes API only by default. |
| **Node exporter** | Chart **4.56.1**, application **1.12.1** | No fixed upstream release was found. The latest application remains **1.12.1**. | Local host collection; no default internet HTTPS client traffic. |
| **Alertmanager** | **Disabled**; application **0.33.1** | No confirmed fixed application release was found; latest **0.34.1** predates the incident. | External notification APIs/webhooks if enabled and configured. |
| **Pushgateway** | **Disabled**; application **1.11.3** | No confirmed fixed application release was found; latest **1.11.4** predates the incident. | Primarily receives metrics; no default internet destination. |

The automation engine also includes cleanup and optional scheduler/descheduler images. Their patch status is **not established** by the controller/gateway result.

## How to interpret MITM risk

- **An attacker still needs interception or redirection capability.** A vulnerable Go version alone does not grant network access.
- **The legitimate server need not use eMudhra certificates.** An attacker could present a fraudulent chain for that server's hostname.
- **Private cluster-CA-only trust reduces this specific exposure.** Publicly trusted control-plane endpoints need separate consideration.
- **Disabling certificate verification defeats this protection.** Inherited Prometheus node/cAdvisor scrape defaults contain `insecure_skip_verify: true`; that is a separate, internal MITM concern.
- **No configured internet destination is not proof of zero egress.** Deployment overrides, injected environment variables, proxies, and runtime behavior can change exposure.

## Recommended order

1. **Upgrade the Prometheus chart to 29.37.2**, after compatibility checks. This covers the server and config reloader, not every exporter.
2. **Use Beyla 3.39.1 explicitly**, or wait for a chart selecting it. Updating only to chart 1.16.15 is insufficient.
3. **Request or rebuild ephemeral-storage metrics with patched Go**, then update its image selection.
4. **Verify the deployed forwarder digest.** Mutable tag `:4` now resolves to patched binaries; existing pods may still run older images.
5. Restrict internet egress to required Kubex/cloud destinations. Keep collectors without external requirements cluster-local.

## Published image evidence

The following multi-platform image digests resolved during the assessment. Go versions were read from the **linux/amd64** application binaries without executing them.

| Image | Resolved image digest | Binary Go version |
| --- | --- | --- |
| `densify/container-optimization-data-forwarder:4` | `sha256:955d854d36becc104d8978734a119a0bc137a7f1bfdcf22418211811a13053b5` | `go1.27.3` for both `dataCollection` and `forwarder` |
| `densify/kubex-connector:1.11.0` | `sha256:543e5715f1463741f863baf90204cad1144fa32fb461719f5c635f7a27801c75` | `go1.27.3` |
| `densify/kubex-ai-cdi:1.11.0` | `sha256:29f9518fdbb4c0b34ffd581de0f75f427aed68cc9cdbbe02ccee61b62285ad6b` | `go1.27.3` |
| `densify/automation-controller:1.16.1` | `sha256:4cc754c0180f5098773e2288fa866c396bf297af1b9c553df29f51f4c306416c` | `go1.27.3` |
| `densify/automation-gateway:1.9` | `sha256:e4038ae6ee128ce85d7aaac2cb3a4570b64192a0dedc0bff0ce4e1ff7ec44ff3` | `go1.27.3` |
| `densify/gpu-process-exporter:1.1.2` | `sha256:965a5aff659fee0e2744d2618b6e8cbfc84e15d55ec08389b5b62ec266b42deb` | `go1.27.3` |
| `densify/node-labeler:0.0.5` | `sha256:609086ca08c0e68911584799b263ae46219893a17d108ece962c2b443f0950b2` | `go1.27.3` |
| `densify/k8s-ephemeral-storage-metrics:1.22.0` | `sha256:d99b05f3bfb2ab9b20592e87168d4d327b06a64ada3c9e33baab3d875e57d3ee` | `go1.26.5` |

## Sources

- [Go vulnerability advisory GO-2026-6809 / CVE-2026-111943](https://pkg.go.dev/vuln/GO-2026-6809)
- [Go advisory JSON](https://vuln.go.dev/ID/GO-2026-6809.json)
- [SOC Prime incident analysis](https://socprime.com/blog/cve-2026-111943-analysis/)
- [Prometheus 3.15.1 security release](https://github.com/prometheus/prometheus/releases/tag/v3.15.1)
- [Prometheus 3.13.5 security backport](https://github.com/prometheus/prometheus/releases/tag/v3.13.5)
- [Prometheus chart 29.37.2 metadata](https://github.com/prometheus-community/helm-charts/blob/prometheus-29.37.2/charts/prometheus/Chart.yaml)
- [Prometheus chart 29.37.2 values](https://github.com/prometheus-community/helm-charts/blob/prometheus-29.37.2/charts/prometheus/values.yaml)
- [Prometheus Operator 0.94.2 security release](https://github.com/prometheus-operator/prometheus-operator/releases/tag/v0.94.2)
- [Beyla 3.39.1 release](https://github.com/grafana/beyla/releases/tag/v3.39.1)
- [Beyla patched Go toolchain change](https://github.com/grafana/beyla/pull/3183)
- [Grafana chart index](https://grafana.github.io/helm-charts/index.yaml)
- [Densify chart index](https://densify-dev.github.io/helm-charts/index.yaml)
- [Prometheus Community chart index](https://prometheus-community.github.io/helm-charts/index.yaml)
- [kube-state-metrics 2.20.0 release](https://github.com/kubernetes/kube-state-metrics/releases/tag/v2.20.0)
- [Node exporter releases](https://github.com/prometheus/node_exporter/releases)
- [Alertmanager releases](https://github.com/prometheus/alertmanager/releases)
- [Pushgateway releases](https://github.com/prometheus/pushgateway/releases)
- [Ephemeral-storage image tags](https://hub.docker.com/r/densify/k8s-ephemeral-storage-metrics/tags)
- Local `Chart.yaml`, `Chart.lock`, `values.yaml`, and vendored archives under `charts/`.

## Limitations

This is a point-in-time release and configuration assessment, not a deployment attestation or packet-capture analysis. Binary checks covered the published Densify **linux/amd64** application images listed above, not ARM64 binaries or every helper image. Running pod digests, deployment-specific overrides, effective trust stores, and observed egress were not checked. Mutable tags can resolve differently over time. No chart configuration was changed during the assessment.
