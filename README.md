# Kubex Helm Charts

<picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://www.kubex.ai/wp-content/uploads/kubex-by-densify-logo-reverse.png">
    <source media="(prefers-color-scheme: light)" srcset="https://www.kubex.ai/wp-content/uploads/kubex-by-densify-logo.png">
    <img src="https://www.kubex.ai/wp-content/uploads/kubex-by-densify-logo.png" width="300">
</picture>

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

## Description

Kubex analyses Kubernetes clusters, produces recommendations for rightsizing resources to mitigate risk and reduce waste, and automates rightsizing.

This repository contains a number of Helm charts.

## Installable Charts

The following charts are meant to be installed by Kubex customers.

1. [Kubex automation stack](https://github.com/densify-dev/helm-charts/tree/master/charts/kubex-automation-stack). This chart bundles all of the components required for Kubex data collection.

2. [Kubex automation engine](https://github.com/densify-dev/helm-charts/tree/master/charts/kubex-automation-engine). This chart is required for automated workload rightsizing and resource optimization.

3. [Kubex automation CRDs](https://github.com/densify-dev/helm-charts/tree/master/charts/kubex-crds). This chart bundles all of the CRDs required by [Kubex automation engine](https://github.com/densify-dev/helm-charts/tree/master/charts/kubex-automation-engine).

4. [Kubex collection GKE Autopilot](https://github.com/densify-dev/helm-charts/tree/master/charts/kubex-collection-gke-autopilot). This chart is an alternative chart for [Kubex automation stack](https://github.com/densify-dev/helm-charts/tree/master/charts/kubex-automation-stack) for **GKE Autopilot clusters only**.

## Deprecated Charts

The following charts are deprecated. **Do not install** these charts.

1. [Kubex automation controller](https://github.com/densify-dev/helm-charts/tree/master/charts/kubex-automation-controller). Replaced by [Kubex automation engine](https://github.com/densify-dev/helm-charts/tree/master/charts/kubex-automation-engine).

2. [Kubex collection Openshift](https://github.com/densify-dev/helm-charts/tree/master/charts/kubex-collection-openshift). Replaced by [Kubex automation stack](https://github.com/densify-dev/helm-charts/tree/master/charts/kubex-automation-stack).

## Subcharts

The following charts are meant to be used **only** as dependencies of the [Installable Charts](#installable-charts). **Do not install** these charts on their own.

1. [Container Optimization Data Forwarder](https://github.com/densify-dev/helm-charts/tree/master/charts/container-optimization-data-forwarder).

2. [K8s Ephemeral Storage Metrics](https://github.com/densify-dev/helm-charts/tree/master/charts/k8s-ephemeral-storage-metrics).

3. [Node Labeler](https://github.com/densify-dev/helm-charts/tree/master/charts/node-labeler).

## Usage

[Helm](https://helm.sh) must be installed to use the charts.
Please refer to Helm's [documentation](https://helm.sh/docs/) to get started.

Once Helm is set up properly, add the Kubex repository and required upstream chart repositories as follows:

```shell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add kubex https://densify-dev.github.io/helm-charts
helm repo update
```

You can then run `helm search repo kubex` to see the charts.

Signed OCI artifacts for Kubex Helm charts are available at [ghcr.io](https://github.com/orgs/densify-dev/packages?repo_name=helm-charts). The OCI artifacts are signed using keyless signing with [Sigstore cosign](https://github.com/sigstore/cosign). The GitHub Pages Helm repository does not use Helm provenance signing.

## License

[Apache 2.0 License](https://github.com/densify-dev/helm-charts/blob/master/LICENSE).
