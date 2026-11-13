# Getting Started with Kubex Automation Engine

This guide walks through installing the chart and validating the current CRD-based automation flow.

## Table of Contents

- [Step 1: Check if Automation Engine is Already Installed](#step-1-check-if-automation-engine-is-already-installed)
- [Step 2: Install or Upgrade the Automation Engine](#step-2-install-or-upgrade-the-automation-engine)
- [Step 3: Create Your First Strategy and Policy](#step-3-create-your-first-strategy-and-policy)
- [Step 4: Validate Automation is Working](#step-4-validate-automation-is-working)
- [Next Steps](#next-steps)
- [Optional: Uninstall and Cleanup](#optional-uninstall-and-cleanup)

---

## Step 1: Check if Automation Engine is Already Installed

Before proceeding with installation, verify whether the automation engine is already running in your cluster. You may have already installed it as part of `kubex-automation-stack` but haven't yet created any policies to activate automation.

**Check for the automation engine controller:**

```bash
kubectl get deployment -n kubex -l app.kubernetes.io/name=kubex-automation-engine
```

**If the automation engine controller is already installed, check the version:**

```bash
# Check current image version
kubectl get deployment -n kubex -l app.kubernetes.io/name=kubex-automation-engine -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'

# Update Helm repo and check latest available version. Add the repo first only if it is not already configured.
helm repo add kubex https://densify-dev.github.io/helm-charts
helm repo update
helm search repo kubex/kubex-automation-engine --versions | head -3
```

**Version Recommendation:** We strongly recommend running the latest version to ensure you have the most recent features, bug fixes, and security updates.

**Next steps:**
- **Controller found and on latest version?** Skip to [Step 3](#step-3-create-your-first-strategy-and-policy) to create policies
- **Controller found but outdated?** Upgrade via [Step 2](#step-2-install-or-upgrade-the-automation-engine) before proceeding
- **No controller found?** Continue to [Step 2](#step-2-install-or-upgrade-the-automation-engine) to install it

## Step 2: Install or Upgrade the Automation Engine

This section covers installation and upgrade procedures for the automation engine. Follow the subsections below in order.

### 2.1 Prepare Required Settings

#### If You Already Have kubex-automation-stack Installed

If you already have `kubex-automation-stack` running in your cluster, you can skip to [2.3 Install or Upgrade the Helm Chart](#23-install-or-upgrade-the-helm-chart) to enable the automation engine. Your existing Kubex credentials and connection settings will be automatically inherited by the automation engine.

#### If You're Installing kubex-automation-stack for the First Time

When installing via the `kubex-automation-stack` chart, your values file will include configuration for both data collection and the automation engine. The automation engine uses the same Kubex credentials and connection settings as the data collection components.

**Important:** The automation engine is disabled by default in the stack chart. You must explicitly set `enabled: true`.

**Minimal stack configuration example:**

```yaml
# Data collection configuration (see stack chart documentation)
stack:
  densify:
    username: your-username
    encrypted_password: your-encrypted-password

container-optimization-data-forwarder:
  config:
    forwarder:
      densify:
        url:
          host: your-instance.kubex.ai
    clusters:
      - name: my-cluster

# Enable automation engine
kubex-automation-engine:
  enabled: true
```

The automation engine will automatically inherit credentials, the Kubex host, and cluster configuration from the data collection components—you do not need to duplicate these settings under `kubex-automation-engine`.

For additional automation engine configuration, such as gateway and webhook settings, nest those values under `kubex-automation-engine`. Resource sizing is covered in [2.2 Choose Your Sizing Overlay](#22-choose-your-sizing-overlay). Manage strategies and policies separately as Kubernetes resources; see [Step 3](#step-3-create-your-first-strategy-and-policy).

For the complete stack configuration structure, including data collection setup, see the [kubex-automation-stack installation guide](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/README.md#installation).

**OpenShift:** If deploying on OpenShift, use the provided [values-openshift.yaml](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/values-openshift.yaml) overlay file. This applies the chart's restricted-friendly OpenShift defaults for both the stack and automation engine components.

#### For Standalone Installation

If installing the `kubex-automation-engine` chart directly (not via the stack), use the provided [kubex-automation-values.yaml](../kubex-automation-values.yaml) template as your starting point and update it with your environment-specific settings. At minimum, make sure these required fields are set:

```yaml
kubex:
  url:
    host: your-instance.kubex.ai
  clusterName: my-cluster

kubexCredentials:
  username: your-username
  epassword: your-encrypted-password
```

If you already manage the Kubex credential secret externally, use this minimal configuration:

```yaml
createSecrets: false

gateway:
  configSecretName: kubex-gateway-config

kubex:
  url:
    host: your-instance.kubex.ai
  clusterName: my-cluster
```

**OpenShift:** If deploying the automation engine standalone on OpenShift, set `openshift.enabled: true` in your values file. This applies the chart's restricted-friendly OpenShift defaults.

#### Secondary/DR Cluster Mode (optional)

If this cluster is acting as a passive (DR) cluster, configure `secondaryCluster` so it follows recommendations from the active cluster.

For `kubex-automation-stack`:

```yaml
kubex-automation-engine:
  enabled: true
  secondaryCluster:
    enabled: true
    primaryClusterName: primary-cluster
```

For standalone installation:

```yaml
secondaryCluster:
  enabled: true
  primaryClusterName: primary-cluster
```

Use this only for active/passive cluster pairs where both clusters run the same workloads with the same namespaces, workload names, workload types, and container names. If the passive cluster has different workloads or different naming, do not enable this mode. For more detail, see [Secondary/DR Cluster Mode](./Configuration-Reference.md#secondarydr-cluster-mode).

#### External Secrets (standalone only)

If you manage the Kubex credential secret externally for standalone installation, create the referenced Secret in the same namespace as the Helm release using the exact keys `username`, `epassword`, `url`, and `DENSIFY_BASE_URL`. For the full Secret format, see [External Credential Secret](./Configuration-Reference.md#external-credential-secret).

### 2.2 Choose Your Sizing Overlay

The stack chart provides initial sizing overlays for its components, including the automation engine, based on the number of managed containers. Choose the overlay that matches your cluster size:

- **Extra Small**: 0–500 containers (`values-xsmall.yaml`)
- **Small**: 500–5,000 containers (`values-small.yaml`)
- **Medium**: 5,001–10,000 containers (`values-medium.yaml`)
- **Large**: 10,001+ containers (`values-large.yaml`)

For stack installations, these overlays configure resource requests and limits for bundled components, including the automation-engine controller manager, gateway sidecar, compaction scheduler, and compaction descheduler.

Download the selected overlay from the [kubex-automation-stack chart](https://github.com/densify-dev/helm-charts/tree/master/charts/kubex-automation-stack) before using it with Helm.

**For kubex-automation-stack users:** Apply the appropriate overlay when installing or upgrading the stack as described in [2.3 Install or Upgrade the Helm Chart](#23-install-or-upgrade-the-helm-chart).

**For standalone installations:** Configure controller, gateway, and other automation-engine resources directly in your values file. The stack sizing overlays are not standalone automation-engine values files.

For detailed sizing values and additional tuning guidance, see the [Configuration Reference](./Configuration-Reference.md) and [Tuning Guide](./Tuning-Guide.md).

### 2.3 Install or Upgrade the Helm Chart

If you have not already added the Kubex Helm repository, run:

```bash
helm repo add kubex https://densify-dev.github.io/helm-charts
helm repo update
```

#### Enable or Upgrade Automation Engine on Existing Stack Installation

If you already have `kubex-automation-stack` installed, use these commands to enable or upgrade the automation engine:

First, ensure the CRDs are installed:

```bash
helm upgrade --install kubex-crds kubex/kubex-crds \
  --namespace kubex \
  --create-namespace
```

Then enable or upgrade the automation engine on your existing stack installation. Use the sizing overlay you identified in [2.2 Choose Your Sizing Overlay](#22-choose-your-sizing-overlay):

```bash
helm upgrade kubex kubex/kubex-automation-stack \
  --namespace kubex \
  --reset-then-reuse-values \
  -f values-small.yaml \
  --set kubex-automation-engine.enabled=true
```

Replace `values-small.yaml` with the appropriate overlay for your cluster size (xsmall, small, medium, or large).

**Note:** The `--reset-then-reuse-values` flag rebuilds the upgrade from chart defaults while preserving your existing data collection configuration. The sizing overlay is reapplied to keep stack and automation-engine resource sizing current, which is especially important if you installed an older version of the stack before automation-engine sizing was added to the overlays.

#### New Stack Installation

If you don't have `kubex-automation-stack` installed yet, see the [kubex-automation-stack installation guide](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/README.md#installation) for complete installation instructions. Make sure to set `kubex-automation-engine.enabled: true` in your values file and install the CRDs as shown above before installing the stack.

#### Standalone Installation or Upgrade

If you previously installed the `kubex-automation-engine` chart standalone (before it was bundled with the stack), you can continue using standalone installation or upgrade:

<details>
<summary>Click to expand standalone installation steps</summary>

Ensure the Helm repository has been added and updated, then ensure the CRDs are installed:

```bash
helm upgrade --install kubex-crds kubex/kubex-crds \
  --namespace kubex \
  --create-namespace
```

Install or upgrade the kubex-automation-engine:

```bash
helm upgrade --install kubex-automation-engine kubex/kubex-automation-engine \
  --namespace kubex \
  --create-namespace \
  -f kubex-automation-values.yaml
```

</details>

**Note:** For new installations, we recommend using the `kubex-automation-stack` instead (see above). If you are migrating from the previous Helm-managed configuration model, see [Migrating from Helm-Managed Configuration](./Migrating-From-Helm-Managed-Config.md).

### 2.4 Verify Controller Health

Check the automation engine controller deployment:

```bash
kubectl get globalconfiguration global-config -o yaml
kubectl get pods -n kubex -l app.kubernetes.io/name=kubex-automation-engine
```

Verify the following checklist:

- [ ] The automation engine controller pod is running and all containers are ready
- [ ] `spec.automationEnabled` is `true`
- [ ] `status.conditions[type=PodAdmissionWebhookHealthy].status` is `True`
- [ ] Review the full `status` block for any error messages
- [ ] Any additional status fields report the expected healthy state for your environment

**Note:** If webhook health is not ready, automation stays paused until probe success reaches the configured threshold.

## Step 3: Create Your First Strategy and Policy

Strategy and policy CRs should be managed separately from the Helm chart using `kubectl`, GitOps, or another external delivery workflow. This keeps the chart focused on installing and operating the controller while allowing strategy and policy configurations to evolve independently.

Before applying a proactive policy, make sure the target workload has a current Kubex recommendation for an in-scope container. Creating the CRs alone does not create a recommendation or immediately resize a workload.

**Note:** For GitOps users, see [GitOps Integration](./GitOps-Integration.md) for details on ownership and why pod-level resizing does not create drift in the original workload manifest.

### Understanding Custom Resources

The automation engine uses custom resources (CRs) to define automation behavior. The main CR patterns are:

- `AutomationStrategy` / `ClusterAutomationStrategy`: define how resizing is allowed to happen, including enablement rules, in-place resize behavior, eviction fallback, and safety checks.
- `ProactivePolicy` / `ClusterProactivePolicy`: define where recommendation-driven automation applies and which strategy to reference.
- `RollbackPolicy` / `ClusterRollbackPolicy`: define health monitoring and automatic rollback conditions to protect production workloads.

Choose the scope based on ownership boundaries:

- Use namespaced CRs when a team should manage automation within its own namespace.
- Use cluster-scoped CRs when a platform team needs one policy model across many namespaces.

**Getting started tip:** Most users should begin with `ClusterAutomationStrategy` and `ClusterProactivePolicy` as shown in the minimal example below.

**Typical workflow:**

1. Create one or more strategy objects that define resize behavior
2. Create policy objects that reference those strategies and target specific workloads
3. Apply the manifests using `kubectl`, GitOps, or another external workflow

### Minimal Example

For a quick start, create a file named `getting-started-policy.yaml` with an explicit strategy enablement example and the minimum fields required for each policy CR. The strategy controls which resize actions are allowed; omitted policy fields use their documented defaults. Replace the placeholder namespace before applying the file.

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterAutomationStrategy
metadata:
  name: example-strategy
spec:
  enablement:
    cpu:
      requests:
        downsize: true
        upsize: true
        setFromUnspecified: true
      limits:
        downsize: true
        upsize: true
        setFromUnspecified: false
    memory:
      requests:
        downsize: true
        upsize: true
        setFromUnspecified: true
      limits:
        downsize: true
        upsize: true
        setFromUnspecified: true
---
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterProactivePolicy
metadata:
  name: example-policy
spec:
  scope:
    namespaceSelector:
      operator: In
      values:
        - your-namespace-here  # Replace with your target namespace(s), or use '*' for cluster-wide
  automationStrategyRef:
    name: example-strategy
---
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterRollbackPolicy
metadata:
  name: example-rollback-policy
spec:
  scope:
    namespaceSelector:
      operator: In
      values:
        - your-namespace-here  # Replace with your target namespace(s), or use '*' for cluster-wide
  monitoringPeriod: 5m
  rollbackTarget: manifest
  adoptionThresholdPercent: 80
```

**Before applying:**
1. Replace `your-namespace-here` in both policies with your actual target namespace(s)
2. Review the strategy enablement settings and adjust which resize actions are allowed for your environment

Save the file and apply it with:

```bash
kubectl apply -f getting-started-policy.yaml
kubectl get clusterautomationstrategy example-strategy
kubectl get clusterproactivepolicy example-policy
kubectl get clusterrollbackpolicy example-rollback-policy
```

For detailed configuration options, see these guides:

- [Automation Strategies](./Automation-Strategies.md) - Namespaced strategy configuration
- [Cluster Automation Strategies](./Cluster-Automation-Strategies.md) - Cluster-wide strategy configuration
- [Proactive Policies](./Proactive-Policies.md) - Recommendation-driven policy configuration
- [Cluster Proactive Policies](./Cluster-Proactive-Policies.md) - Cluster-wide recommendation-driven policies
- [Rollback Policies](./Rollback-Policies.md) - Health monitoring and automatic rollback configuration
- [Policy Configuration](./Policy-Configuration.md) - Strategy and policy model overview

For detailed configuration options, including enablement, health checks, in-place resize behavior, eviction fallback, safety controls, and rollback backoff, see:
- [Cluster Automation Strategies](./Cluster-Automation-Strategies.md) - Full strategy configuration reference
- [Cluster Proactive Policies](./Cluster-Proactive-Policies.md) - Full policy configuration reference
- [Rollback Policies](./Rollback-Policies.md) - Full namespaced and cluster rollback policy reference

## Step 4: Validate Automation is Working

After creating policies, verify that automation is working correctly.

**Check policy objects (all namespaces):**

```bash
kubectl get proactivepolicy,clusterproactivepolicy,rollbackpolicy,clusterrollbackpolicy -A
kubectl get automationstrategy,clusterautomationstrategy -A
kubectl get events -A --field-selector reason=PrecheckFailed
```

**Validate admission annotations on a specific pod:**

```bash
# Replace <pod-name> and <namespace> with your actual pod and namespace
kubectl get pod <pod-name> -n <namespace> -o go-template='{{range $k,$v := .metadata.annotations}}{{printf "%s\n" $k}}{{end}}' | grep -E 'rightsizing\\.kubex\\.ai/|automation-webhook\\.kubex\\.ai/pod-rightsizing-info'
```

**Expected output:** You should see annotations like:
- `cwproactive.rightsizing.kubex.ai/desired-resource-requests` (for the cluster-scoped example)
- `cwproactive.rightsizing.kubex.ai/desired-resource-limits` (for the cluster-scoped example)
- `automation-webhook.kubex.ai/pod-rightsizing-info`

The `cwproactive...` annotations show that the recommendation controller propagated the policy recommendation to the pod. The `automation-webhook...` annotation records pod rightsizing processing; together with the policy evaluation events and summary logs below, these confirm that the automation flow processed the pod.

**Validate pod events (in your target namespace):**

```bash
# Check events in a specific namespace where policies apply
kubectl get events -n <namespace> --sort-by=.lastTimestamp | grep -E 'PolicyEvaluationSelected|PolicyEvaluationInPlaceResize|PolicyEvaluationEvictResize|PrecheckFailed'
```

**Validate controller summary logs:**

```bash
kubectl logs -n kubex -l control-plane=controller-manager -c manager --since=10m | grep 'rightsizing summary'
```

Look for results such as `RESIZED`, `EVICTED`, `BLOCKED_RETRYING`, or `BLOCKED`. These indicate the controller is actively processing workloads.

## Next Steps

1. If the workload is not being resized, use the [Troubleshooting](./Troubleshooting.md) guide to inspect policy scope, safety filters, webhook health, events, and summary logs.
2. Refine the strategy and policy behavior using the [Policy Configuration](./Policy-Configuration.md) guide and the detailed [Cluster Automation Strategies](./Cluster-Automation-Strategies.md) and [Cluster Proactive Policies](./Cluster-Proactive-Policies.md) references.
3. Review [Safety Controls](./Safety-Controls.md) and [Rollback Policies](./Rollback-Policies.md) before enabling automation for production workloads.
4. Manage the strategy and policy CRs through [GitOps Integration](./GitOps-Integration.md) once the configuration is working as intended.
5. For Helm-level changes, sizing adjustments, or slow-cluster tuning, see the [Configuration Reference](./Configuration-Reference.md) and [Tuning Guide](./Tuning-Guide.md).

## Optional: Uninstall and Cleanup

To cleanly remove the automation engine, delete custom resources before uninstalling the Helm release.

### Delete Custom Resources First

Delete policies and strategies before uninstalling the Helm chart. This allows the running controller to properly clean up Kubex annotations from workloads.

```bash
kubectl delete proactivepolicy,clusterproactivepolicy,rollbackpolicy,clusterrollbackpolicy -A --all
kubectl delete automationstrategy,clusterautomationstrategy -A --all
```

**Wait for deletion to complete:**

```bash
kubectl get proactivepolicy,clusterproactivepolicy,rollbackpolicy,clusterrollbackpolicy,automationstrategy,clusterautomationstrategy -A
```

The output should show "No resources found" when cleanup is complete.

**Note:** If resources get stuck in `Terminating` state, see the [Troubleshooting Guide](./Troubleshooting.md) for finalizer removal procedures.

### Uninstall the Helm Release

**For stack installation:**

```bash
helm uninstall kubex --namespace kubex
```

**For standalone installation:**

```bash
helm uninstall kubex-automation-engine --namespace kubex
```

### Optionally Remove CRDs

If you want to completely remove CRDs from the cluster:

```bash
helm uninstall kubex-crds --namespace kubex
```

**Warning:** Only remove CRDs after all custom resources are deleted. Removing CRDs while CRs exist will leave orphaned resources.
