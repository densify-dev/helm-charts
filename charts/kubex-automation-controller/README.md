# Kubex Automation Controller

Enterprise-grade Kubernetes resource optimization automation with intelligent policy-driven container resizing.

## ⚠️ Important Notice

**This chart should NOT be installed directly.**

Use the [kubex-automation-stack](../kubex-automation-stack) chart instead, which includes this automation controller along with all necessary components for comprehensive Kubex container optimization (data collection, automation, and monitoring).

The standalone installation of this chart is deprecated and no longer supported.

## For New Installations

Please refer to the [kubex-automation-stack documentation](../kubex-automation-stack/README.md) for installation instructions.

---

## Legacy Documentation

The information below is maintained for reference purposes only and applies to the deprecated standalone installation.

# Quick Links (Legacy - For Reference Only)

- [Kubex Automation Controller](#kubex-automation-controller)
- [Important Notice](#️-important-notice)
- [For New Installations](#for-new-installations)
- [Legacy Documentation](#legacy-documentation)
- [Quick Links (Legacy - For Reference Only)](#quick-links-legacy---for-reference-only)
- [Overview](#overview)
  - [Core Components](#core-components)
  - [Key Features](#key-features)
  - [Supported Resource Types](#supported-resource-types)
- [Legacy Getting Started (Deprecated)](#legacy-getting-started-deprecated)
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

**Note:** This component is now part of [kubex-automation-stack](../kubex-automation-stack). For new deployments, use the stack chart instead.

Kubex Automation Controller provides intelligent, policy-driven automation for managing container resource configurations in Kubernetes clusters. It safely and efficiently resizes workload resources based on optimization recommendations while respecting your operational constraints.

## Core Components

The deployment consists of several key services:

- **🎯 Automation Controller**: Fetches optimization recommendations, evaluates policies, and safely applies resizing actions
- **🔄 Mutating Admission Webhook**: Real-time pod optimization during creation
- **📊 Valkey Cache**: High-performance in-memory store for recommendations and state management

## Key Features

- **🚀 Automated Resizing**: Dynamic CPU and memory optimization based on actual usage patterns
- **⚡ Zero-Downtime Optimization**: In-place container resizing without pod restarts (Kubernetes 1.33+) with automatic fallback to pod eviction
- **🛡️ Safety-First Approach**: Multi-layered validation including HPA awareness, LimitRange compliance, ResourceQuota checking, node allocatable capacity validation, PodDisruptionBudget respect, and configurable pod eviction delays
- **⏸️ Smart Pause Control**: Per-pod annotation-based pausing for learning periods after application changes or permanent exclusions
- **📋 Policy-Driven**: Configurable automation rules for downsizing, upsizing, and constraint handling
- **🎯 Flexible Targeting**: Multiple scope configurations for different automation behaviors across cluster regions
- **📈 Enterprise Ready**: RBAC integration, audit trails, and GitOps compatibility

## Supported Resource Types

By default, automation applies to: `Deployment`, `StatefulSet`, `CronJob`, `Rollout`, `Job`, `ReplicaSet`, `AnalysisRun`

> **Note**: `DaemonSet` is supported but excluded by default for safety. Can be enabled via policy configuration.

---

# Legacy Getting Started (Deprecated)

**⚠️ Warning:** Standalone installation is deprecated. Use [kubex-automation-stack](../kubex-automation-stack) instead.

<details>
<summary>Click to expand legacy getting started guide</summary>

Ready to deploy? Follow our step-by-step guide:

**👉 [Getting Started Guide](./docs/Getting-Started.md)**

This guide covers:
- Prerequisites and requirements
- Configuration file setup  
- Certificate management options (self-signed by default, cert-manager optional)
- Deployment verification
- First automation policies

</details>

---

# Documentation

**⚠️ For current documentation, see [kubex-automation-stack documentation](../kubex-automation-stack/README.md)**

<details>
<summary>Click to expand legacy documentation references</summary>

## Configuration

| Document | Purpose |
|----------|---------|
| **[Getting Started](./docs/Getting-Started.md)** | Step-by-step deployment guide |
| **[Configuration Reference](./docs/Configuration-Reference.md)** | Complete field-by-field reference for `kubex-automation-values.yaml` |
| **[Policy Configuration](./docs/Policy-Configuration.md)** | Define automation behaviors and safety rules |
| **[Apply Updates](./docs/Getting-Started.md#step-8-deploy)** | Rerun the deploy script or `helm upgrade --install … -f kubex-automation-values.yaml` after configuration changes |

## Advanced Topics

| Document | Purpose |
|----------|---------|
| **[Advanced Configuration](./docs/Advanced-Configuration.md)** | Node scheduling, performance tuning, enterprise features |
| **[Pod Scan Configuration](./docs/Pod-Scan-Configuration.md)** | Optimize scanning performance for large clusters |
| **[RBAC Permissions](./docs/RBAC-Guide.md)** | Security model and permission breakdown |
| **[GitOps Integration](./docs/GitOps-Integration.md)** | Argo CD, Flux, and drift prevention |

## Reference

| Document | Purpose |
|----------|---------|
| **[Troubleshooting](./docs/Troubleshooting.md)** | Common issues and diagnostic procedures |
| **[Known Issues](./docs/Known-Issues.md)** | Current limitations and workarounds |

</details>

---

# FAQ

Have questions? Check our **[Frequently Asked Questions](./docs/FAQ.md)** covering:

- 🚀 **Getting Started**: Requirements, deployment time, safety
- ⚙️ **Configuration**: Scope vs policy, exclusions, testing changes  
- 🔒 **Security & Safety**: Permissions, damage prevention, emergency procedures
- ⚡ **Performance**: Cluster limits, API impact, resource usage
- 🔧 **Troubleshooting**: Common issues and debugging steps
- 🎯 **Advanced Usage**: High availability, monitoring, large clusters

---

# Support

## Getting Help

- **📖 Documentation Issues**: Check our comprehensive [Troubleshooting Guide](./docs/Troubleshooting.md)
- **🐛 Bug Reports**: Include logs from all components and configuration details
- **💡 Feature Requests**: Submit enhancement proposals with use cases

## Diagnostic Collection

```bash
# Quick diagnostic collection
kubectl logs -l app=kubex-controller -n kubex --all-containers=true > controller.log
kubectl logs -l app=kubex-webhook -n kubex --all-containers=true > webhook.log
kubectl get configmap,secret -n kubex -o yaml > config.yaml
```

---

# License

Apache 2.0 Licensed. See [LICENSE](LICENSE) for full details.