# Configuration Reference (`kubex-automation-values.yaml`)

This document provides a detailed reference for every field in your `kubex-automation-values.yaml` file. Each section includes guidance on which values must be copied from the Kubex UI and which require manual input based on your environment.

# Quick Links

- [Configuration Reference (`kubex-automation-values.yaml`)](#configuration-reference-kubex-automation-valuesyaml)
- [Quick Links](#quick-links)
  - [⚠️ Important: Configuration Update Requirements](#️-important-configuration-update-requirements)
    - [Policy Updates vs. Scope/New Policy Changes](#policy-updates-vs-scopenew-policy-changes)
      - [✅ Policy Updates (Safe to edit ConfigMap directly)](#-policy-updates-safe-to-edit-configmap-directly)
      - [⚠️ Scope Changes \& New Policies (Requires Helm upgrade)](#️-scope-changes--new-policies-requires-helm-upgrade)
    - [Why Scope Changes Are Different](#why-scope-changes-are-different)
    - [Correct Update Procedures](#correct-update-procedures)
      - [For Policy Setting Changes:](#for-policy-setting-changes)
      - [For Scope Changes or New Policies:](#for-scope-changes-or-new-policies)
    - [What Gets Updated During Helm Upgrade](#what-gets-updated-during-helm-upgrade)
    - [Summary Guidelines](#summary-guidelines)
  - [Resources Created by This Chart](#resources-created-by-this-chart)
    - [Core Application Components](#core-application-components)
    - [Configuration \& Secrets](#configuration--secrets)
    - [RBAC \& Security](#rbac--security)
    - [Certificate Management (if cert-manager enabled)](#certificate-management-if-cert-manager-enabled)
    - [Storage \& Cache](#storage--cache)
  - [Connection Parameters (from Kubex UI)](#connection-parameters-from-kubex-ui)
  - [Cluster Configuration (Manual Input)](#cluster-configuration-manual-input)
    - [Certificate Management](#certificate-management)
  - [Scope Definition (Manual Input)](#scope-definition-manual-input)
    - [Adding Multiple Scopes](#adding-multiple-scopes)
    - [Field Reference](#field-reference)
  - [Deployment Configuration (Optional)](#deployment-configuration-optional)
    - [Pod Scan Configuration](#pod-scan-configuration)
    - [Eviction Throttling](#eviction-throttling)
    - [Advanced Controller Settings](#advanced-controller-settings)
  - [Resource Optimization (Recommended)](#resource-optimization-recommended)
    - [Optimizing Kubex Components](#optimizing-kubex-components)
    - [Deployment Resource Overrides](#deployment-resource-overrides)
    - [Valkey Resource Overrides](#valkey-resource-overrides)
  - [Policy Settings](#policy-settings)
  - [Valkey Configuration (Manual Input)](#valkey-configuration-manual-input)
    - [Generating a Valkey Password](#generating-a-valkey-password)
  - [Local Storage Configuration](#local-storage-configuration)

## ⚠️ Important: Configuration Update Requirements

**CRITICAL OPERATIONAL NOTE:** Different types of configuration changes require different update procedures.

### Policy Updates vs. Scope/New Policy Changes

#### ✅ Policy Updates (Safe to edit ConfigMap directly)
If you need to **modify existing policy settings** (e.g., change CPU/memory thresholds, enable/disable features), you can update the ConfigMap directly:

```bash
# Edit existing policy settings
kubectl edit configmap kubex-automation-policy -n kubex
```

The automation controller will pick up these changes within ~60 seconds without requiring pod restarts.

#### ⚠️ Scope Changes & New Policies (Requires Helm upgrade)
The following changes **MUST** be done via Helm upgrade:
- Adding or removing scope definitions
- Adding new policies to the `policy.policies` section
- Changing namespace or pod label selectors
- Modifying which policy a scope uses

### Why Scope Changes Are Different

The scope configuration is used in **two places simultaneously**:

1. **MutatingWebhookConfiguration** - Tells Kubernetes which pods to intercept and send to the webhook server
2. **ConfigMap** (`kubex-automation-scope`) - Tells the automation controller which pods to process for optimization

If you edit the scope ConfigMap directly:
- ✅ **Automation Controller**: Uses the new scope from the updated ConfigMap
- ❌ **Webhook Server**: Still uses the old scope from the MutatingWebhookConfiguration  
- 🚨 **Result**: Components become out of sync, leading to unpredictable behavior

### Correct Update Procedures

#### For Policy Setting Changes:
```bash
# Option 1: Direct ConfigMap edit (immediate effect)
kubectl edit configmap kubex-automation-policy -n kubex

# Option 2: Helm upgrade (consistent with other changes)
vim kubex-automation-values.yaml
helm upgrade <release-name> . -f kubex-automation-values.yaml
```

#### For Scope Changes or New Policies:
```bash
# 1. Edit your configuration
vim kubex-automation-values.yaml

# 2. Apply changes via Helm upgrade
helm upgrade <release-name> . -f kubex-automation-values.yaml

# 3. Verify both components are updated
kubectl get mutatingwebhookconfiguration kubex-resource-optimization-webhook -o yaml
kubectl get configmap kubex-automation-scope -n kubex -o yaml
```

### What Gets Updated During Helm Upgrade

- ✅ MutatingWebhookConfiguration (webhook server scope)  
- ✅ ConfigMaps (automation controller scope and policies)
- ✅ Secrets (if credentials changed)
- ✅ All other Kubernetes resources as needed

### Summary Guidelines

| Change Type | ConfigMap Edit | Helm Upgrade | Notes |
|-------------|----------------|--------------|-------|
| **Policy settings** (automation enablement settings) | ✅ Safe | ✅ Also works | ConfigMap changes take effect in ~60 seconds |
| **Scope definitions** (namespaces, pod labels) | ❌ Dangerous | ✅ Required | Must keep webhook and controller in sync |
| **New policies** | ❌ Incomplete | ✅ Required | Policy must exist in both places |
| **Policy assignments** (which policy a scope uses) | ❌ Dangerous | ✅ Required | Must update both webhook and ConfigMap |

---

## Resources Created by This Chart

When you deploy the Kubex Automation Controller, the following Kubernetes resources are created:

### Core Application Components
| Resource Type | Name | Purpose |
| --- | --- | --- |
| **Deployment** | `kubex-automation-controller` | Main controller that processes recommendations and applies optimizations |
| **Deployment** | `kubex-webhook-server` | Mutating admission webhook for real-time pod optimization |
| **Service** | `kubex-webhook-service` | Service exposing the webhook server |

### Configuration & Secrets
| Resource Type | Name | Purpose |
| --- | --- | --- |
| **ConfigMap** | `kubex-config` | Stores cluster name and Densify API base URL |
| **ConfigMap** | `kubex-automation-policy` | Contains automation policies and rules |
| **ConfigMap** | `kubex-automation-scope` | Defines which namespaces/workloads are in scope |
| **ConfigMap** | `kubex-automation-controller-clusterrole` | RBAC rules for the controller |
| **Secret** | `kubex-api-secret-container-automation` | Densify API credentials |
| **Secret** | `kubex-valkey-client-auth` | Credentials for connecting to Valkey cache |
| **Secret** | `kubex-valkey-secret` | Valkey server configuration with auth settings |

### RBAC & Security
| Resource Type | Name | Purpose |
| --- | --- | --- |
| **ServiceAccount** | `kubex-automation-controller-sa` | Service account for the controller |
| **ServiceAccount** | `kubex-mutating-webhook-sa` | Service account for the webhook |
| **ClusterRole** | `kubex-automation-controller-role` | Permissions for reading/updating Kubernetes resources |
| **ClusterRoleBinding** | `kubex-automation-controller-rb` | Binds the ClusterRole to ServiceAccounts |
| **MutatingWebhookConfiguration** | `kubex-resource-optimization-webhook` | Registers the webhook with Kubernetes API |

### Certificate Management (if cert-manager enabled)
| Resource Type | Name | Purpose |
| --- | --- | --- |
| **ClusterIssuer** | `kubex-selfsigned-cluster-issuer` | Creates self-signed certificates |
| **Certificate** | `kubex-automation-cert` | TLS certificate for webhook communication |

### Storage & Cache
| Resource Type | Name | Purpose |
| --- | --- | --- |
| **EmptyDir Volume** | `recommendations-volume` | Local storage for recommendations (ephemeral) |
| **Deployment** | `kubex-automation-controller-valkey` | Valkey cache instance (from subchart) |
| **Service** | `kubex-automation-controller-valkey` | Service for Valkey cache (from subchart) |

---

## Connection Parameters (from Kubex UI)

These parameters must be **copied directly** from the Kubex UI:

| Key                             | Description                                                 |
| ------------------------------- | ----------------------------------------------------------- |
| `densify.url.host`              | Your Densify instance URL. Format: `<instance>.densify.com` |
| `densifyCredentials.username`  | The username used for accessing the Densify API             |
| `densifyCredentials.epassword` | The encrypted password for the API user                     |


## Cluster Configuration (Manual Input)

| Key                   | Description                                                  |
| --------------------- | ------------------------------------------------------------ |
| `cluster.name`        | Name of the Kubernetes cluster as recognized in Densify      |
| `certmanager.enabled` | Set to `true` to use cert-manager for certificate management |

### Certificate Management

**Using cert-manager (Default)**
When `certmanager.enabled: true`, certificates are automatically managed:
- A self-signed ClusterIssuer is created
- TLS certificates are generated and rotated automatically
- The CA bundle is injected into the MutatingWebhookConfiguration

**Using Custom Certificates**
When `certmanager.enabled: false`, you must provide your own certificates:

1. **Create the required secret:**
   ```bash
   kubectl create secret generic kubex-automation-tls \
     --from-file=tls.crt=your-cert.pem \
     --from-file=tls.key=your-key.pem \
     --from-file=ca.crt=your-ca.pem \
     -n kubex
   ```

2. **Secret requirements:**
   - `tls.crt`: Your TLS certificate with required DNS names (see [Certificates-BYOC.md](Certificates-BYOC.md))
   - `tls.key`: Private key for the certificate
   - `ca.crt`: **Required** - CA certificate that signed the TLS certificate

3. **Why the CA certificate is required:**
   - The kubex-automation-controller mounts the CA certificate at `/densify/tls/ca.crt`
   - The MutatingWebhookConfiguration uses the CA certificate in its `caBundle` field
   - Without the CA certificate, webhook admission requests will fail

See [Certificates-BYOC.md](Certificates-BYOC.md) for complete custom certificate requirements.


## Scope Definition (Manual Input)

Defines which pods are eligible for automation using namespace and label filters. Each scope references a policy that defines automation behavior. Multiple scopes allow different automation rules for different parts of your cluster.

### Adding Multiple Scopes

To configure multiple scopes for different environments or teams:

1. Copy the entire scope block (from `- name:` to the end of `podLabels:`)
2. Paste it below the existing scope and modify:
   - Change the scope name to be unique
   - Reference a different policy if desired  
   - Adjust namespace and label filters

**Example: Multiple scopes for different environments**
```yaml
scope:
  - name: production-scope
    policy: conservative-policy
    namespaces:
      operator: In
      values: ["prod-*"]
    podLabels:
      - key: env
        operator: In
        values: ["production"]
        
  - name: development-scope
    policy: aggressive-policy
    namespaces:
      operator: In
      values: ["dev-*", "staging-*"]
    podLabels:
      - key: env
        operator: In
        values: ["development", "staging"]
```

### Field Reference

| Field                  | Description                                                                                                                               |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `scope[].name`         | Unique name for this scope definition.                                                                                                    |
| `scope[].policy`       | **Policy name to use** (must match a named policy defined in [Policy Configuration](Policy-Configuration.md)). |
| `scope[].namespaces`   | **Mandatory** - Namespace filter configuration that defines which namespaces to include/exclude.                                          |
| `namespaces.operator`  | `In` or `NotIn` – whether to include or exclude listed namespaces.                                                                        |
| `namespaces.values`    | List of namespaces to include/exclude. Always exclude `kubex` namespace.  These namespaces are excluded by default: kube-node-lease, kube-public and kube-system.                                  |
| `scope[].podLabels`    | **Mandatory** - List of pod label selector blocks for filtering based on pod labels.                                                     |
| `podLabels[].key`      | Pod label key to evaluate (e.g., "app", "env", "tier").                                                                                   |
| `podLabels[].operator` | `In` or `NotIn` – how to evaluate label values.                                                                                           |
| `podLabels[].values`   | List of values for the given label key.                                                                                                   |



## Deployment Configuration (Optional)

The deployment section allows you to override default controller behavior and tune performance for your cluster size and requirements.

### Pod Scan Configuration

For clusters with many pods, you may need to adjust scan timing. See [Pod-Scan-Configuration.md](Pod-Scan-Configuration.md) for detailed guidance.

| Field                                | Description                                                                                    |
| ------------------------------------ | ---------------------------------------------------------------------------------------------- |
| `deployment.controllerEnv.podScanInterval`            | How often the controller scans all pods for optimization opportunities (default: 6h45m)       |
| `deployment.controllerEnv.podScanTimeout`             | Maximum time allowed for a complete pod scanning cycle (default: 6h30m)                       |
| `deployment.controllerEnv.podEvictionCooldownPeriod`  | Wait time between individual pod evictions. Default: 1m (allows for resource quotas and termination grace periods). Use 10-15s for aggressive resizing. Use longer cooldowns (2-5m) for: large images/no cache, heavy cluster load, slow API server. |

### Eviction Throttling

Control the rate of pod evictions across the entire cluster to prevent overwhelming your infrastructure during large-scale optimization events.

| Field                                | Description                                                                                    |
| ------------------------------------ | ---------------------------------------------------------------------------------------------- |
| `deployment.controllerEnv.evictionThrottlingWindow`   | Time window for counting pod evictions (e.g., "6h", "24h")                                    |
| `deployment.controllerEnv.evictionThrottlingMax`      | Maximum number of pod evictions allowed within the time window                                 |

**Example: Limit to 1000 pod evictions per 6 hours**
```yaml
deployment:
  controllerEnv:
    evictionThrottlingWindow: "6h"
    evictionThrottlingMax: "1000"
```

**Use Cases:**
- **Large cluster deployments**: Prevent overwhelming cluster during initial automation rollout
- **Production safety**: Limit automation impact during business hours
- **Rolling updates**: Control eviction rate during major application deployments
- **Infrastructure protection**: Prevent cascading failures from too many simultaneous pod changes

### Advanced Controller Settings

Additional controller behavior configuration:

| Field                                | Description                                                                                    |
| ------------------------------------ | ---------------------------------------------------------------------------------------------- |
| `deployment.controllerEnv.recommendationsFetchInterval`    | How often to fetch fresh recommendations from Kubex API (default: 1h)                        |
| `deployment.controllerEnv.recommendationsResyncTimeout`    | Maximum time for recommendation synchronization operations (default: 45m)                     |
| `deployment.controllerEnv.recommendationDataFormat`        | Storage format in Valkey: "json" (readable) or "protobuf" (compact, default)                 |
| `deployment.controllerEnv.nodeCpuHeadroom`                 | CPU headroom to reserve on each node (e.g., "100m" or "10%")                                  |
| `deployment.controllerEnv.nodeMemoryHeadroom`              | Memory headroom to reserve on each node (e.g., "200Mi" or "10%")                              |
| `deployment.controllerEnv.debug`                           | Enable debug logging for troubleshooting (true/false)                                         |

## Resource Optimization (Recommended)

**Important**: Kubex cannot automate its own components. Monitor the controller, webhook, and Valkey pods in Densify UI and manually optimize their resources based on recommendations.

### Optimizing Kubex Components

1. **Monitor in Densify**: Check recommendations for `kubex-automation-controller`, `kubex-webhook`, and `kubex-valkey` pods
2. **Override resources** in your `kubex-automation-values.yaml` based on Densify recommendations
3. **Apply changes**: Run `helm upgrade kubex-automation-controller . -f kubex-automation-values.yaml`

### Deployment Resource Overrides

| Field                           | Description                                                                                       |
| ------------------------------- | ------------------------------------------------------------------------------------------------- |
| `deployment.webhookResources`   | Resource specifications for the webhook server pod. Update based on Densify recommendations.     |
| `deployment.gatewayResources`   | CPU and memory resource requests and limits for the gateway pod. Update based on recommendations.|
| `deployment.controllerResources`| Resource specifications for the controller pod. Update based on Densify recommendations.        |

### Valkey Resource Overrides

| Field                    | Description                                                                                                |
| ------------------------ | ---------------------------------------------------------------------------------------------------------- |
| `valkey.resources`       | Resource sizing for Valkey cache (tune for your cluster/workload). Update based on Densify recommendations.|

**Example Configuration:**
```yaml
deployment:
  webhookResources:
    requests:
      memory: "128Mi"    # Update based on Densify recommendations
      cpu: "200m"
    limits:
      memory: "256Mi"
  gatewayResources:
    requests:
      memory: "256Mi"    # Update based on Densify recommendations
      cpu: "500m"
    limits:
      memory: "512Mi"
  controllerResources:
    requests:
      memory: "256Mi"    # Update based on Densify recommendations
      cpu: "500m"
    limits:
      memory: "1Gi"

valkey:
  resources:
    requests:
      cpu: "500m"        # Update based on Densify recommendations
      memory: "512Mi"
    limits:
      memory: "1Gi"
```



## Policy Settings

The `policy` section of your `kubex-automation-values.yaml` file configures automation behavior, global flags, and connects scopes to named policies.

**📖 For complete policy configuration details**, see the [Policy Configuration Guide](Policy-Configuration.md), which covers:
- Policy naming requirements (RFC 1123 rules)
- Field reference for all policy settings  
- Adding multiple policies
- Common policy examples (`base-optimization`, `full-optimization`)

The policy section structure:
```yaml
policy:
  automationEnabled: true          # Global automation switch
  defaultPolicy: base-optimization # Default policy name
  remoteEnablement: false          # UI override control
  policies:                        # Named policy definitions
    base-optimization: { ... }     # Policy settings
```



## Valkey Configuration (Manual Input)

This section configures the credentials and storage for the embedded Valkey cache, which is used for storing recommendations and state.

| Key                          | Description                                                                                             |
| ------------------------------ | ------------------------------------------------------------------------------------------------------- |
| `valkey.credentials.user`       | The username for accessing the Valkey instance. Defaults to `"kubexAutomation"` if not set.             |
| `valkey.credentials.password`   | **Required.** The password for the Valkey instance. Must be quoted if it includes special characters, cannot include SPACES. |
| `valkey.storage.className`      | **Optional.** The storage class to use for Valkey persistent storage (e.g., `gp2` for EKS, `azurefile` for AKS, `standard` for GKE). Define if your environment requires it. |
| `valkey.storage.requestedSize`  | Storage capacity for Valkey persistent volume. Default: `10Gi`.                                        |
| `valkey.resources`             | Resource specifications for Valkey pod. Can be overridden based on Densify recommendations.             |

### Generating a Valkey Password

Generate a strong random password for the Valkey cache using one of these methods:

```bash
# Generate a 32-character random password (recommended)
openssl rand -base64 32

# Generate a 24-character alphanumeric password (alternative)
openssl rand -base64 18 | tr -d "=+/" | cut -c1-24

# Generate using pwgen (if available)
pwgen -s 32 1
```

Copy the generated password and use it in your `kubex-automation-values.yaml` under `valkey.credentials.password`.

**Example `kubex-automation-values.yaml`:**
```yaml
valkey:
  credentials:
    user: "kubexAutomation"
    password: "<your-secret-password>"
  storage:
    className: "gp3-csi"  # For Valkey persistent storage
```

## Local Storage Configuration

The Densify Automation Controller now uses **emptyDir** volumes for local storage instead of PersistentVolumeClaims. This approach provides several benefits:

- **Simplified deployment**: No need to provision PVCs or manage storage classes
- **Better scheduling**: Pods can run on any node without volume constraints
- **Faster updates**: No volume attachment delays during rolling updates
- **Cloud-agnostic**: Works consistently across all Kubernetes environments

The recommendation data is ephemeral and regenerated as needed. For persistent data requirements, Valkey provides caching and state management.
