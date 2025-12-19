# Configuration Reference (`kubex-automation-values.yaml`)

This document provides a detailed reference for every field in your `kubex-automation-values.yaml` file. Each section includes guidance on which values must be copied from the Kubex UI and which require manual input based on your environment.

## How to Use This Reference

- Populate `kubex-automation-values.yaml` section by section using the tables below.
- Need the deployment workflow? Stay in [Getting Started](./Getting-Started.md).
- For rollout or future edits, update `kubex-automation-values.yaml` and rerun either the deploy script or the `helm upgrade --install … -f kubex-automation-values.yaml` command from [Getting Started Step 8](./Getting-Started.md#step-8-deploy).
- Cross-reference dedicated guides (Policy Configuration, Certificates, Pod Scan Configuration) for deeper explanations.

---

## Resources Created by This Chart

### Core Application Components

| Resource Type | Name | Purpose |
| --- | --- | --- |
| **Deployment** | `kubex-automation-controller` | Main controller that processes recommendations and applies optimizations |
| **Deployment** | `kubex-webhook-server` | Mutating admission webhook for real-time pod optimization |
| **Service** | `kubex-webhook-service` | Service exposing the webhook server |

### ConfigMaps

| Name | Purpose |
| --- | --- |
| `kubex-config` | Stores cluster name and Kubex API base URL |
| `kubex-automation-policy` | Contains automation policies and rules |
| `kubex-automation-scope` | Defines which namespaces/workloads are in scope |
| `kubex-automation-controller-clusterrole` | RBAC rules for the controller |

### Secrets

If the value `createSecrets` is `false`, the helm chart does not create any secrets by itself but rather uses the secret names provided in the "override" values.

| Default Name | Purpose | Value to override name |
| --- | --- | ---- |
| `kubex-api-secret-container-automation` | Kubex API credentials | `densifyCredentials.userSecretName` |
| `kubex-valkey-client-auth` | Credentials for connecting to Valkey cache |  `valkey.metrics.exporter.extraExporterEnvSecrets[0]` |
| `kubex-valkey-secret` | Valkey server configuration with auth settings | `valkey.extraSecretValkeyConfigs` |

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

## Secret Management Configuration

Use `createSecrets` to decide whether Helm renders all required secrets or you supply them externally. This flag covers the Kubex API secret, both Valkey secrets, and the webhook TLS secret.

| Key | Type | Description |
|-----|------|-------------|
| `createSecrets` | `boolean` | `true` = Helm renders all secrets; `false` = you reference pre-existing secrets |

- `createSecrets: true` → populate the credential values below and follow [Valkey Configuration with Secret Creation](#valkey-configuration-with-secret-creation). Choose a TLS method (self-signed default, cert-manager, or BYOC).
- `createSecrets: false` → supply secret names instead of raw credentials, following [Valkey Configuration with External Secrets](#valkey-configuration-with-external-secrets) plus [TLS Certificate Secret (External Secret Management)](#tls-certificate-secret-external-secret-management).

## Connection Parameters with Secret Creation

Copy these fields from the Kubex UI when `createSecrets: true`.

| Key                            | Description                                                 |
| ------------------------------ | ----------------------------------------------------------- |
| `densify.url.host`             | Your Kubex instance URL. Format: `<instance>.densify.com` |
| `densifyCredentials.username`  | The username used for accessing the Kubex API             |
| `densifyCredentials.epassword` | The encrypted password for the API user                     |

## Connection Parameters with External Secret

When `createSecrets: false`, reference the secret name that already stores the API credentials.

| Key                                 | Description                                                 |
| ----------------------------------- | ----------------------------------------------------------- |
| `densify.url.host`                  | Your Kubex instance URL. Format: `<instance>.densify.com` |
| `densifyCredentials.userSecretName` | Kubex API secret name                                     |

### API Secret Format

The API secret must be in the same namespace the helm chart is deployed, and must have this format:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <Kubex API secret name>
  namespace: <helm chart namespace>
type: Opaque
stringData:
  DENSIFY_USERNAME: "<username>"
  DENSIFY_EPASSWORD: "<encrypted password>"
```

## Cluster Configuration (Manual Input)

| Key                   | Description                                                  |
| --------------------- | ------------------------------------------------------------ |
| `cluster.name`        | Name of the Kubernetes cluster as recognized in Kubex      |

**Note**: TLS certificate method is controlled by the deploy script (see [Certificate Management](#certificate-management) below), not by settings in `kubex-automation-values.yaml`.

### Certificate Management

| Method | Deploy command | Notes |
|--------|----------------|-------|
| Helm-generated self-signed | `./deploy-kubex-automation-controller.sh` | Default, 10-year validity, requires `createSecrets: true` |
| cert-manager | `./deploy-kubex-automation-controller.sh --certmanager` | cert-manager must already exist; rotates every 30 days |
| BYOC | `createSecrets: false` + manual secret | Follow [Certificates-BYOC.md](Certificates-BYOC.md) and [TLS Certificate Secret](#tls-certificate-secret-external-secret-management) |

## Scope Definition (Manual Input)

See [Getting Started Step 5](./Getting-Started.md#step-5-define-automation-scope) for workflow guidance. Use this table to map each YAML field.

### Field Reference

| Field                  | Description                                                                                                                               |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `scope[].name`         | Unique name for this scope definition.                                                                                                    |
| `scope[].policy`       | **Policy name to use** (must match a named policy defined in [Policy Configuration](Policy-Configuration.md)). |
| `scope[].namespaces`   | **Mandatory** - Namespace filter configuration that defines which namespaces to include/exclude.                                          |
| `namespaces.operator`  | `In` or `NotIn` – whether to include or exclude listed namespaces.                                                                        |
| `namespaces.values`    | List of namespaces to include/exclude. Always exclude `kubex` namespace.  These namespaces are excluded by default: kube-node-lease, kube-public and kube-system.                                  |
| `scope[].podLabels`    | **Optional** - List of pod label selector blocks for filtering based on pod labels.                                                     |
| `podLabels[].key`      | Pod label key to evaluate (e.g., "app", "env", "tier").                                                                                   |
| `podLabels[].operator` | `In` or `NotIn` – how to evaluate label values.                                                                                           |
| `podLabels[].values`   | List of values for the given label key.                                                                                                   |

## Deployment Configuration (Optional)

### Pod Scan Configuration

For clusters with many pods, you may need to adjust scan timing. See [Pod-Scan-Configuration.md](Pod-Scan-Configuration.md) for detailed guidance.

| Field                                | Description                                                                                    |
| ------------------------------------ | ---------------------------------------------------------------------------------------------- |
| `deployment.controllerEnv.podScanInterval`            | How often the controller scans all pods for optimization opportunities (default: 1h, optimized for in-place resizing on Kubernetes 1.33+). See Pod-Scan-Configuration.md for pod eviction mode settings. |
| `deployment.controllerEnv.podScanTimeout`             | Maximum time allowed for a complete pod scanning cycle (default: 30m, optimized for in-place resizing)                       |
| `deployment.controllerEnv.podScanInitialInterval`     | Initial delay before the first pod scan after controller startup (default: 2m)               |
| `deployment.controllerEnv.podEvictionCooldownPeriod`  | Wait time between individual pod evictions (default: 1m). Only used when in-place resizing is unavailable (Kubernetes < 1.33 or policy inPlaceResize.enabled: false). Allows for resource quotas and termination grace periods. Use 15s for aggressive resizing. Use longer cooldowns (2-5m) for: large images/no cache, heavy cluster load, slow API server. |

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
| `deployment.controllerEnv.recommendationsFetchInitialDelay` | Startup delay before first recommendation fetch from Kubex API (default: 1m)                 |
| `deployment.controllerEnv.recommendationsFetchInterval`    | How often to fetch fresh recommendations from Kubex API (default: 1h)                        |
| `deployment.controllerEnv.recommendationsResyncTimeout`    | Maximum time for recommendation synchronization operations (default: 45m)                     |
| `deployment.controllerEnv.recommendationDataFormat`        | Storage format in Valkey: "json" (readable) or "protobuf" (compact, default)                 |
| `deployment.controllerEnv.nodeCpuHeadroom`                 | CPU headroom to reserve on each node (e.g., "100m" or "10%")                                  |
| `deployment.controllerEnv.nodeMemoryHeadroom`              | Memory headroom to reserve on each node (e.g., "200Mi" or "10%")                              |
| `deployment.controllerEnv.debug`                           | Enable debug logging for troubleshooting (true/false)                                         |

## Resource Optimization (Recommended)

Kubex components cannot optimize themselves. Review their recommendations in Kubex and override resources here.

### Deployment Resource Overrides

| Field                           | Description                                                                                       |
| ------------------------------- | ------------------------------------------------------------------------------------------------- |
| `deployment.webhookResources`   | Resource specifications for the webhook server pod. Update based on Kubex recommendations.     |
| `deployment.gatewayResources`   | CPU and memory resource requests and limits for the gateway pod. Update based on recommendations.|
| `deployment.controllerResources`| Resource specifications for the controller pod. Update based on Kubex recommendations.        |

### Valkey Resource Overrides

| Field                    | Description                                                                                                |
| ------------------------ | ---------------------------------------------------------------------------------------------------------- |
| `valkey.resources`       | Resource sizing for Valkey cache (tune for your cluster/workload). Update based on Kubex recommendations.|

**Example Configuration:**
```yaml
deployment:
  webhookResources:
    requests:
      memory: "128Mi"    # Update based on Kubex recommendations
      cpu: "200m"
    limits:
      memory: "256Mi"
  gatewayResources:
    requests:
      memory: "256Mi"    # Update based on Kubex recommendations
      cpu: "500m"
    limits:
      memory: "512Mi"
  controllerResources:
    requests:
      memory: "256Mi"    # Update based on Kubex recommendations
      cpu: "500m"
    limits:
      memory: "1Gi"

valkey:
  resources:
    requests:
      cpu: "500m"        # Update based on Kubex recommendations
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

## Generating a Valkey Password

Generate a strong random password for the Valkey cache using one of these methods:

```bash
# Generate a 32-character random password (recommended)
openssl rand -base64 32

# Generate a 24-character alphanumeric password (alternative)
openssl rand -base64 18 | tr -d "=+/" | cut -c1-24

# Generate using pwgen (if available)
pwgen -s 32 1
```

Copy the generated password and use it in your `kubex-automation-values.yaml` under `valkey.credentials.password` (if `createSecrets` is `true`) or use it in the two secrets (if `createSecrets` is `false`).

## Valkey Configuration

The following sections configure the credentials, storage and other optional parameters for the embedded Valkey cache, which is used for storing recommendations and state.

## Valkey Configuration with Secret Creation

If `createSecrets` is `true`:

| Key                          | Description                                                                                             |
| ------------------------------ | ------------------------------------------------------------------------------------------------------- |
| `valkey.credentials.user`       | The username for accessing the Valkey instance. Defaults to `"kubexAutomation"` if not set.             |
| `valkey.credentials.password`   | **Required.** The password for the Valkey instance. Must be quoted if it includes special characters, cannot include SPACES. |
| `valkey.storage.className`      | **Optional.** The storage class to use for Valkey persistent storage (e.g., `gp2` for EKS, `azurefile` for AKS, `standard` for GKE). Define if your environment requires it. |
| `valkey.storage.requestedSize`  | Storage capacity for Valkey persistent volume. Default: `10Gi`.                                        |
| `valkey.resources`             | Resource specifications for Valkey pod. Can be overridden based on Kubex recommendations.             |
| `valkey.nodeSelector`           | **Optional.** Node labels for valkey scheduling. Define if your environment requires it. |
| `valkey.affinity`               | **Optional.** Valkey pod affinity. Define if your environment requires it. |
| `valkey.tolerations`           | **Optional.** Node tolerations for valkey scheduling to nodes with taints. Define if your environment requires it. |
| `valkey.topologySpreadConstraints` | **Optional.** Valkey pod topology spread constraints. Define if your environment requires it. |

In this case, `kubex-automation-values.yaml` will look like this:

```yaml
createSecrets: true
# ...
valkey:
  credentials:
    user: "kubexAutomation"
    password: "{your-secret-password}"
  # ...
```

## Valkey Configuration with External Secrets

If `createSecrets` is `false`:

| Key                          | Description                                                                                             |
| ------------------------------ | ------------------------------------------------------------------------------------------------------- |
| `valkey.extraSecretValkeyConfigs`   | **Required.** This is the secret name which includes the valkey server `auth.conf`. |
| `valkey.metrics.exporter.extraExporterEnvSecrets`   | **Required.** This is a list of secret names. It should include **only** one value, which is the secret name to be used by all valkey clients. |
| `valkey.storage.className`      | **Optional.** The storage class to use for Valkey persistent storage (e.g., `gp2` for EKS, `azurefile` for AKS, `standard` for GKE). Define if your environment requires it. |
| `valkey.storage.requestedSize`  | Storage capacity for Valkey persistent volume. Default: `10Gi`.                                        |
| `valkey.resources`             | Resource specifications for Valkey pod. Can be overridden based on Kubex recommendations.             |
| `valkey.nodeSelector`           | **Optional.** Node labels for valkey scheduling. Define if your environment requires it. |
| `valkey.affinity`               | **Optional.** Valkey pod affinity. Define if your environment requires it. |
| `valkey.tolerations`           | **Optional.** Node tolerations for valkey scheduling to nodes with taints. Define if your environment requires it. |
| `valkey.topologySpreadConstraints` | **Optional.** Valkey pod topology spread constraints. Define if your environment requires it. |

In this case, `kubex-automation-values.yaml` will look like this:

```yaml
createSecrets: false
# ...
valkey:
  extraSecretValkeyConfigs: "{valkey-server-secret-name}"
  metrics:
    exporter:
      extraExporterEnvSecrets:
        - "{valkey-client-secret-name}"
  # ...
```

Replace `{valkey-username}` and `{valkey-password}` with the same values in both secrets:

### Valkey Server Secret Format

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {valkey-server-secret-name}
  namespace: {helm chart namespace}
type: Opaque
stringData:
  # These lines are appended to valkey.conf
  # Disable the default user and enable a named user with a password.
  # Quote password if they contain special characters. Password may not contain spaces.
  auth.conf: |
    user default off
    user {valkey-username} on >'{valkey-password}' +@all ~*
```

### Valkey Client Secret Format

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {valkey-client-secret-name}
  namespace: {helm chart namespace}
type: Opaque
stringData:
  # Used by the redis exporter, automation controller and webhook to connect to Valkey
  REDIS_USER: "{valkey-username}"
  REDIS_PASSWORD: "{valkey-password}"
```

---

## TLS Certificate Secret (External Secret Management)

When `createSecrets: false`, you have two options for TLS certificates:

1. **Use cert-manager** - Run deploy script with `--certmanager` flag (see [Certificate Management](#certificate-management))
2. **Use BYOC** - Provide your own certificate as described below

**If using BYOC (not cert-manager):**

The chart does NOT generate certificates for external secret management. You must provide your own certificate (BYOC). Since Helm-generated certificates are created at template rendering time, they cannot be extracted for external secret management.

**Steps to provide your own certificate:**

1. **Generate or obtain a TLS certificate** with the following DNS names:
   - `kubex-webhook-service`
   - `kubex-webhook-service.kubex`
   - `kubex-webhook-service.kubex.svc`
   - `kubex-webhook-service.kubex.svc.cluster.local`

2. **Create the secret** in your external secret management system (Vault, AWS Secrets Manager, etc.) with three keys:
   ```yaml
   tls.crt: <your-certificate-pem-data>
   tls.key: <your-private-key-pem-data>
   ca.crt: <your-ca-certificate-pem-data>
   ```

3. **Sync the secret to Kubernetes** using your secret management tool (External Secrets Operator, Sealed Secrets, etc.) to create the `kubex-automation-tls` secret in the `kubex` namespace.

4. **Verify the secret exists:**
   ```bash
   kubectl get secret kubex-automation-tls -n kubex
   ```

**Alternative: Manual Secret Creation**

If not using external secret management, create the secret manually:

```bash
kubectl create secret generic kubex-automation-tls \
  --from-file=tls.crt=your-cert.pem \
  --from-file=tls.key=your-key.pem \
  --from-file=ca.crt=your-ca.pem \
  --type=kubernetes.io/tls \
  -n kubex
```

**Certificate Generation:**

For BYOC requirements and guidelines, see [Certificates-BYOC.md](Certificates-BYOC.md).
