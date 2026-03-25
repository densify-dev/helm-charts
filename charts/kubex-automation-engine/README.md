# Kubex Automation Engine

Enterprise-grade Kubernetes resource optimization with policy-driven rightsizing, admission-time mutation, and proactive resize execution.

> [!IMPORTANT]
> `kubex-automation-engine` is still in pre-release status. For production-grade automation, use the [`kubex-automation-engine`](../kubex-automation-engine/README.md) chart.

# Quick Links

- [Kubex Automation Engine](#kubex-automation-engine)
- [Quick Links](#quick-links)
- [Overview](#overview)
  - [Core Components](#core-components)
  - [Key Features](#key-features)
  - [Supported Resources](#supported-resources)
- [Getting Started](#getting-started)
- [Documentation](#documentation)
  - [Configuration](#configuration)
  - [Advanced Topics](#advanced-topics)
  - [Reference](#reference)
- [FAQ](#faq)
- [Support](#support)
  - [Getting Help](#getting-help)
  - [Diagnostic Collection](#diagnostic-collection)
- [License](#license)

---

# Overview

Kubex Automation Engine uses Custom Resources to separate automation behavior from workload targeting:

- `AutomationStrategy` and `ClusterAutomationStrategy` define how rightsizing is allowed to happen
- `ProactivePolicy` and `ClusterProactivePolicy` define where recommendation-driven automation applies
- `StaticPolicy` and `ClusterStaticPolicy` define fixed resource settings instead of recommendation-driven automation
- `GlobalConfiguration` defines cluster-wide controller behavior such as recommendation refresh, rescans, and webhook health gating

The Helm chart supports both Helm-managed configuration and manually managed custom resources. 

Important:

- The Helm-managed `scope` and `policy.policies` values preserve the existing values-driven flow from `values-edit.yaml` by generating `AutomationStrategy` and `ClusterProactivePolicy`, but those CRs can also be created and managed independently of Helm
- `ProactivePolicy`, `StaticPolicy`, `ClusterStaticPolicy`, and `ClusterAutomationStrategy` are supported by the controller but are managed as separate CR manifests today

## Core Components

The deployment consists of these key pieces:

- **Kubex automation engine deployment**: the single `kubex-automation-engine` deployment evaluates policies, enforces safety checks, executes in-place resize or eviction-based resize, and serves the admission webhooks
- **Mutating admission webhook configuration**: registers the pod mutation webhook that applies rightsizing to newly created pods at admission time
- **Gateway sidecar**: runs alongside the controller in the same deployment and retrieves recommendations from Kubex
- **Custom Resources**: store global configuration, strategies, policies, and runtime evaluation state

## Key Features

- **Declarative automation model**: define strategies and policies as CRDs or generate them directly from Helm values
- **Recommendation-driven and static policy support**: automate rightsizing from live recommendations or enforce fixed resource settings where predictability matters more
- **Zero-downtime optimization**: use in-place container resizing without pod restarts on Kubernetes 1.33+, with automatic fallback to pod eviction when needed
- **Namespaced and cluster-scoped control**: apply automation patterns at team scope or standardize them across the entire cluster
- **Admission-time and proactive enforcement**: optimize new pods at creation time and continuously evaluate existing workloads
- **Fail-closed safety model**: combine webhook health gating with HPA/VPA filtering, quota and LimitRange checks, node headroom validation, readiness checks, and protected namespaces
- **Smart pause control**: pause automation per pod with annotations for learning periods after application changes or for permanent exclusions
- **GitOps-friendly adoption path**: keep baseline automation in Helm, layer additional CRs through GitOps or `kubectl`, and preserve backward compatibility with existing environment-variable-based settings during migration

## Supported Resources

Recommendation-driven automation can target these workload owners when included by policy:

- `Deployment`
- `StatefulSet`
- `CronJob`
- `Rollout`
- `Job`
- `AnalysisRun`
- `DaemonSet` when explicitly allowed by policy

---

# Getting Started

Ready to deploy and validate your first automation flow?

**👉 [Getting Started Guide](./docs/Getting-Started.md)**

This guide covers:

- Prerequisites and required connection settings
- Helm installation with generated default CRs
- OpenShift note: install still requires cluster-scoped permissions for RBAC and admission webhook resources; set `openshift.enabled=true` for the chart's restricted-friendly OpenShift path, and only set `openshift.fsGroup` if your cluster policy requires it
- Namespaced and cluster-scoped CR examples
- How to verify webhook health, policy resolution, and recommendation application
- How to uninstall cleanly, including manual finalizer cleanup for externally managed CRs

---

# Documentation

## Configuration

| Document | Purpose |
|----------|---------|
| **[Getting Started](./docs/Getting-Started.md)** | Step-by-step install, first strategy/policy, and validation workflow |
| **[Configuration Reference](./docs/Configuration-Reference.md)** | Current Helm values, generated resources, and CR mapping reference |
| **[Global Configuration Reference](./docs/Global-Configuration.md)** | Field-by-field reference for the `GlobalConfiguration` custom resource |
| **[Policy Configuration](./docs/Policy-Configuration.md)** | Configure strategies, policy scope, precedence, and Helm-managed policy generation |
| **[Apply Updates](./docs/Getting-Started.md#apply-configuration-updates)** | Re-run `helm upgrade` after configuration changes |

## Advanced Topics

| Document | Purpose |
|----------|---------|
| **[Advanced Configuration](./docs/Advanced-Configuration.md)** | Global configuration, pause controls, safety controls, and operating patterns |
| **[Global Configuration Reference](./docs/Global-Configuration.md)** | Detailed `GlobalConfiguration` fields, defaults, Helm mapping, and timing behavior |
| **[Safety Controls Reference](./docs/Safety-Controls.md)** | Pre-checks, filters, evaluation order, and `failedChecks` / `appliedFilters` interpretation |
| **[RBAC Permissions](./docs/RBAC-Guide.md)** | Controller and webhook permission model |

## Reference

| Document | Purpose |
|----------|---------|
| **[Safety Controls Reference](./docs/Safety-Controls.md)** | Runtime safety-control names, messages, and debugging reference |
| **[Troubleshooting](./docs/Troubleshooting.md)** | Interpret runtime events, `rightsizing summary` logs, and health conditions |
| **[Known Issues](./docs/Known-Issues.md)** | Current limitations, behavior notes, and operational caveats |
| **[FAQ](./docs/FAQ.md)** | Common deployment, configuration, and safety questions |

---

# FAQ

Have questions? Start with **[Frequently Asked Questions](./docs/FAQ.md)** covering:

- Getting started and prerequisites
- Helm-managed versus manual CR management
- Safety controls and emergency stop options
- Troubleshooting and verification steps

For the detailed safety runtime reference, see **[Safety Controls Reference](./docs/Safety-Controls.md)**.

---

# Support

## Getting Help

- **Documentation issues**: start with the [Troubleshooting Guide](./docs/Troubleshooting.md)
- **Configuration questions**: compare your setup against the [Configuration Reference](./docs/Configuration-Reference.md)
- **Upgrade and migration questions**: review the backward compatibility notes in [Advanced Configuration](./docs/Advanced-Configuration.md#backward-compatibility-and-migration)

## Diagnostic Collection

```bash
kubectl get globalconfiguration global-config -o yaml
kubectl get clusterproactivepolicy,proactivepolicy,clusterstaticpolicy,staticpolicy,clusterautomationstrategy,automationstrategy -A
kubectl get events -A --field-selector reason=PrecheckFailed
kubectl logs -n kubex -l control-plane=controller-manager -c manager --since=10m | grep 'rightsizing summary'
```

---

# License

Apache 2.0 Licensed. See `LICENSE` for full details.
