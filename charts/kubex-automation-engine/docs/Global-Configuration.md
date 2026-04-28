# Global Configuration

`GlobalConfiguration` defines cluster-wide controller behavior that applies across strategies and policies.

Use it to control recommendation refresh timing, proactive rescans, global automation switches, protected namespaces, and webhook health thresholds.

## Field Reference

| Field | Default | Description |
| --- | --- | --- |
| `spec.recommendationReloadInterval` | `1h` | How often recommendations are reloaded from Kubex. |
| `spec.rescanInterval` | `6h` | How often workloads are rescanned for proactive evaluation. |
| `spec.mutationLogInterval` | `5m` | How often mutation logs are sent. |
| `spec.snapshotInterval` | `30m` | How often policy snapshots are sent. |
| `spec.kubexAPIRequestTimeout` | `30s` | Timeout for Kubex API requests. |
| `spec.automationEnabled` | `true` | Global on or off switch for automation behavior. |
| `spec.suppressFetchRecommendations` | `false` | Testing-oriented switch to suppress recommendation fetches. |
| `spec.respectKubexAutomation` | `true` | Ignores recommendations marked with `KubexAutomation=false`. |
| `spec.protectedNamespacePatterns` | `["kube-*","openshift-*"]` | Namespace glob patterns excluded from automation. |
| `spec.webhookHealth.failureThreshold` | `2` | Failed probes required before webhook health becomes unhealthy. |
| `spec.webhookHealth.successThreshold` | `3` | Successful probes required before webhook health becomes healthy. |
| `spec.webhookHealth.transitionCheckInterval` | `10s` | Probe interval used during webhook health transitions. |

## Status Reference

| Field | Description |
| --- | --- |
| `status.recommendationReload.lastTime` | Timestamp of the most recent successful recommendation reload. |
| `status.recommendationReload.lastCount` | Number of recommendations loaded by the most recent successful recommendation reload. |
| `status.recommendationReload.lastError` | Last recommendation reload error message, if any. |
| `status.recommendationReload.lastErrorTime` | Timestamp of the most recent recommendation reload failure. |
| `status.recommendationReload.proactiveRescanPending` | Whether a proactive rescan is pending because recommendations changed. |
| `status.recommendationReload.proactiveRescanPendingTime` | When the pending proactive rescan was requested. |
| `status.rescan.lastTime` | Timestamp of the most recent policy rescan. |
| `status.webhookHealth.*` | Current webhook probe streaks and last probe metadata. |

## Example

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: GlobalConfiguration
metadata:
  name: global-config
spec:
  recommendationReloadInterval: 1h
  rescanInterval: 6h
  mutationLogInterval: 5m
  snapshotInterval: 30m
  kubexAPIRequestTimeout: 30s
  automationEnabled: true
  suppressFetchRecommendations: false
  respectKubexAutomation: true
  protectedNamespacePatterns:
    - "kube-*"
    - "openshift-*"
    - "kubex-*"
  webhookHealth:
    failureThreshold: 2
    successThreshold: 3
    transitionCheckInterval: 10s
```

## Helm-Managed Mapping

The chart creates a default `GlobalConfiguration` when `globalConfiguration.enabled=true`.

| Helm value | Renders to | Notes |
| --- | --- | --- |
| `globalConfiguration.enabled` | resource creation toggle | Helm-only switch, not a CR field |
| `globalConfiguration.recommendationReloadInterval` | `spec.recommendationReloadInterval` | Falls back to legacy value if unset |
| `globalConfiguration.rescanInterval` | `spec.rescanInterval` | Falls back to legacy value if unset |
| `globalConfiguration.mutationLogInterval` | `spec.mutationLogInterval` | Direct mapping |
| `globalConfiguration.snapshotInterval` | `spec.snapshotInterval` | Direct mapping |
| `globalConfiguration.kubexAPIRequestTimeout` | `spec.kubexAPIRequestTimeout` | Falls back to legacy value if unset |
| `globalConfiguration.automationEnabled` | `spec.automationEnabled` | Direct mapping |
| `globalConfiguration.suppressFetchRecommendations` | `spec.suppressFetchRecommendations` | Direct mapping |
| `globalConfiguration.respectKubexAutomation` | `spec.respectKubexAutomation` | Direct mapping |
| `globalConfiguration.protectedNamespacePatterns` | `spec.protectedNamespacePatterns` | Supports `*` wildcard matching |
| `globalConfiguration.webhookHealth.failureThreshold` | `spec.webhookHealth.failureThreshold` | Direct mapping |
| `globalConfiguration.webhookHealth.successThreshold` | `spec.webhookHealth.successThreshold` | Direct mapping |
| `globalConfiguration.webhookHealth.transitionCheckInterval` | `spec.webhookHealth.transitionCheckInterval` | Direct mapping |

Legacy `deployment.controllerEnv` values still act as fallbacks for the default `GlobalConfiguration`:

| Legacy value | Effective field |
| --- | --- |
| `deployment.controllerEnv.recommendationsFetchInterval` | `spec.recommendationReloadInterval` |
| `deployment.controllerEnv.podScanInterval` | `spec.rescanInterval` |
| `deployment.controllerEnv.apiRequestTimeout` | `spec.kubexAPIRequestTimeout` |

If both the new `globalConfiguration.*` value and the legacy value are set, the `globalConfiguration.*` value wins.

## Webhook Probe Image Runtime Setting

The pod admission webhook health probe creates a dry-run Pod. The container image used for that probe is configured at deployment runtime, not in `GlobalConfiguration.spec`:

- Helm value: `controllerManager.webhookProbeImage`
- Container env var: `WEBHOOK_PROBE_IMAGE`
- Default behavior: when unset or empty, the probe image inherits the controller image (`image.repository:image.tag`)

This allows airgapped environments to mirror only the controller image and have probe admissions use that same image by default.
On EKS clusters, the probe pod is labeled with `eks.amazonaws.com/skip-pod-identity-webhook: "true"` so the AWS-managed pod identity webhook skips this dry-run probe admission.
## Verification

Use these commands to inspect the rendered and live resource:

```bash
helm template kubex-automation . | sed -n '/^kind: GlobalConfiguration/,+25p'
kubectl get globalconfiguration global-config -o yaml
```

## Related

- For cluster-wide operating guidance, see [Advanced Configuration](./Advanced-Configuration.md).
- For Helm values, see [Configuration Reference](./Configuration-Reference.md).
- For protected namespaces and recommendation filtering, see [Safety Controls Reference](./Safety-Controls.md).
