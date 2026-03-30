# Getting Started with Kubex Automation Engine

This guide walks through installing the chart and validating the current CRD-based automation flow.

> [!IMPORTANT]
> `kubex-automation-engine` is still in pre-release status. For production-grade automation, use the [`kubex-automation-controller`](https://github.com/densify-dev/helm-charts/tree/master/charts/kubex-automation-controller) chart instead.

# Quick Links

- [Getting Started with Kubex Automation Engine](#getting-started-with-kubex-automation-engine)
- [Quick Links](#quick-links)
  - [Prerequisites](#prerequisites)
  - [Step 1: Prepare Required Settings](#step-1-prepare-required-settings)
  - [Step 2: Container Resource Sizing Guidance](#step-2-container-resource-sizing-guidance)
    - [Controller manager (`resources`)](#controller-manager-resources)
    - [Gateway sidecar (`gateway.resources`)](#gateway-sidecar-gatewayresources)
  - [Step 3: Install the Helm Chart](#step-3-install-the-helm-chart)
  - [Step 4: Verify Controller Health](#step-4-verify-controller-health)
  - [Step 5: Create Your First Strategy and Policy](#step-5-create-your-first-strategy-and-policy)
    - [Option A: Helm-managed](#option-a-helm-managed)
    - [Option B: External CR Management](#option-b-external-cr-management)
  - [Step 6: Validate Recommendation Application](#step-6-validate-recommendation-application)
  - [Apply Configuration Updates](#apply-configuration-updates)
  - [Uninstall](#uninstall)
    - [Remove externally managed CRs first](#remove-externally-managed-crs-first)
    - [Manually remove finalizers from external CRs only if deletion is stuck](#manually-remove-finalizers-from-external-crs-only-if-deletion-is-stuck)
    - [Uninstall the Helm releases](#uninstall-the-helm-releases)
  - [Next Steps](#next-steps)

---

## Prerequisites

Before you begin, ensure you have:

- Kubernetes 1.28+
- Helm 3+
- `kubectl` access to the target cluster
- The [`kubex-crds` chart](https://github.com/densify-dev/helm-charts/tree/master/charts/kubex-crds) installed in the target cluster before installing `kubex-automation-engine`
- Kubex connection details from the Automation tab in the Kubex UI
- A target workload that already has valid Kubex recommendations

Important:

- Proactive rightsizing only works when a valid recommendation exists for the in-scope container
- Recommendations are typically available about 24 hours after data collection starts


## Step 1: Prepare Required Settings

Use the provided [kubex-automation-values.yaml](../kubex-automation-values.yaml) template as your starting point and update it with your environment-specific settings. At minimum, make sure these required fields are set:

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

Then create the referenced Secret in the same namespace as the Helm release using the exact keys `username`, `epassword`, `url`, and `DENSIFY_BASE_URL`. For the full Secret format, see [External Credential Secret](./Configuration-Reference.md#external-credential-secret).

If you are deploying on OpenShift, also set `openshift.enabled: true` in your values file to apply the chart's restricted-friendly OpenShift defaults.

## Step 2: Container Resource Sizing Guidance

Container resource requests and limits should be adjusted based on the number of managed containers in the cluster. Use these values as a starting point and tune them based on workload churn, recommendation volume, and webhook traffic.

### Controller manager (`resources`)

| Resource       | Small (0-1K) | Medium (1K-10K) | Large (10K+) |
|----------------|--------------|-----------------|--------------|
| CPU Request    | 25m          | 200m            | 400m         |
| CPU Limit      | -            | -               | -            |
| Memory Request | 500Mi        | 2Gi             | 4Gi          |
| Memory Limit   | 1Gi          | 4Gi             | 6Gi          |

### Gateway sidecar (`gateway.resources`)

| Resource       | Small (0-1K) | Medium (1K-10K) | Large (10K+) |
|----------------|--------------|-----------------|--------------|
| CPU Request    | 15m          | 15m             | 25m          |
| CPU Limit      | -            | -               | -            |
| Memory Request | 40Mi         | 60Mi            | 90Mi         |
| Memory Limit   | 250Mi        | 350Mi           | 500Mi        |

Sizing notes:

- `Small` means up to 1,000 managed containers
- `Medium` means 1,000 to 10,000 managed containers
- `Large` means more than 10,000 managed containers
- The chart currently exposes sizing controls for the controller manager and gateway sidecar; the older webhook and Valkey components do not apply to this chart

Example values:

```yaml
resources:
  requests:
    cpu: 200m
    memory: 2Gi
  limits:
    memory: 4Gi

gateway:
  resources:
    requests:
      cpu: 15m
      memory: 60Mi
    limits:
      memory: 350Mi
```

## Step 3: Install the Helm Chart

Add the Kubex Helm repository on the machine where you run Helm:

```bash
helm repo add kubex https://densify-dev.github.io/helm-charts
helm repo update
```

Install the CRDs first:

```bash
helm install kubex-crds kubex/kubex-crds \
  --namespace kubex \
  --create-namespace
```

Then install the kubex-automation-engine:

```bash
helm install kubex-automation-engine kubex/kubex-automation-engine \
  --namespace kubex \
  --create-namespace \
  -f kubex-automation-values.yaml
```

Optional:

- Define `scope` and `policy.policies` in the same values file to have Helm generate `ClusterAutomationStrategy` and `ClusterProactivePolicy` resources
- This Helm-managed path is mainly available for backward compatibility with the previous automation controller configuration model
- Prefer keeping `scope` empty and managing strategy and policy CRs outside Helm with `kubectl` or GitOps
- Create `StaticPolicy` or `ClusterStaticPolicy` separately if you want fixed resource values instead of recommendation-driven automation for specific workloads

## Step 4: Verify Controller Health

Check the deployment:

```bash
kubectl get pods -n kubex
kubectl get globalconfiguration global-config -o yaml
```

Confirm:

- The controller pod is running
- `spec.automationEnabled` is `true`
- Review the full `status` block, not just `status.conditions`
- `status.conditions[type=PodAdmissionWebhookHealthy].status` is `True`
- Any additional status fields that report controller readiness, webhook health, last sync, or reconciliation errors reflect the expected healthy state for your environment

If webhook health is not ready, automation stays paused until probe success reaches the configured threshold.


## Step 5: Create Your First Strategy and Policy

### Option A: Helm-managed

This path is mainly provided for backward compatibility with the previous automation controller, where automation behavior was driven from Helm values.

For new setups, prefer Option B so strategy and policy CRs are managed outside Helm and can evolve independently of chart upgrades.

If you need the backward-compatible Helm-managed flow, define both a policy and a scope in your values file:

```yaml
scope:
  - name: team-a
    policy: base-optimization
    namespaces:
      operator: In
      values:
        - team-a
    podLabels:
      - key: app
        operator: In
        values:
          - demo

policy:
  defaultPolicy: base-optimization
  policies:
    base-optimization:
      allowedPodOwners: "Deployment,StatefulSet,CronJob,Rollout,Job"
      enablement:
        cpu:
          request:
            downsize: true
            upsize: true
            setFromUnspecified: true
          limit:
            downsize: false
            upsize: true
            setFromUnspecified: false
        memory:
          request:
            downsize: true
            upsize: true
            setFromUnspecified: true
          limit:
            downsize: false
            upsize: true
            setFromUnspecified: true
      inPlaceResize:
        enabled: true
      podEviction:
        enabled: true
      safetyChecks:
        maxAnalysisAgeDays: 5
```

Apply it with `helm upgrade`. Helm will render the corresponding `ClusterAutomationStrategy` and `ClusterProactivePolicy` resources from these values.

### Option B: External CR Management

This is the preferred approach. Keep the chart focused on installing and operating the controller, and manage strategy and policy CRs separately with `kubectl`, GitOps, or another external delivery workflow.

The main CR patterns are:

- `AutomationStrategy` / `ClusterAutomationStrategy`: define how resizing is allowed to happen, including enablement rules, in-place resize behavior, eviction fallback, and safety checks.
- `ProactivePolicy` / `ClusterProactivePolicy`: define where recommendation-driven automation applies and which strategy to reference.
- `StaticPolicy` / `ClusterStaticPolicy`: define where fixed request/limit values should be enforced and which strategy to reference.

Choose the scope based on ownership boundaries:

- Use namespaced CRs when a team should manage automation within its own namespace.
- Use cluster-scoped CRs when a platform team needs one policy model across many namespaces.

Start with these guides, each with field references and fuller examples:

- Strategy configuration: [Automation Strategies](./Automation-Strategies.md)
- Cluster-wide strategy configuration: [Cluster Automation Strategies](./Cluster-Automation-Strategies.md)
- Recommendation-driven policy configuration: [Proactive Policies](./Proactive-Policies.md)
- Cluster-wide recommendation-driven policy configuration: [Cluster Proactive Policies](./Cluster-Proactive-Policies.md)
- Fixed-resource policy configuration: [Static Policies](./Static-Policies.md)
- Strategy and policy model overview: [Policy Configuration](./Policy-Configuration.md)

A typical external-CR workflow looks like this:

1. Install or upgrade the controller with Helm without including `scope` / `policy` sections.
2. Create one or more `AutomationStrategy` or `ClusterAutomationStrategy` objects for the resize behaviors you want.
3. Create `ProactivePolicy`, `ClusterProactivePolicy`, `StaticPolicy`, or `ClusterStaticPolicy` objects that reference those strategies.
4. Apply and reconcile those manifests through `kubectl`, GitOps, or another external workflow.

For a minimal start-to-finish example, create a cluster strategy that uses the default automation enablement settings and a cluster proactive policy that targets a few namespaces:

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterAutomationStrategy
metadata:
  name: getting-started-defaults
spec: {}
---
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterProactivePolicy
metadata:
  name: getting-started-apps
spec:
  scope:
    namespaceSelector:
      operator: In
      values:
        - team-a
        - team-b
        - staging
  automationStrategyRef:
    name: getting-started-defaults
```

Apply it with:

```bash
kubectl apply -f getting-started-policy.yaml
kubectl get clusterautomationstrategy getting-started-defaults
kubectl get clusterproactivepolicy getting-started-apps
```

This gives you a working baseline without needing to set every field up front. Expand the strategy or narrow the policy scope later as you validate behavior in your cluster.

This pattern lets you tune strategy behavior and policy scope independently from Helm upgrades.

## Step 6: Validate Recommendation Application

Check policy objects:

```bash
kubectl get proactivepolicy,clusterproactivepolicy,staticpolicy,clusterstaticpolicy -A
kubectl get automationstrategy,clusterautomationstrategy -A
kubectl get events -A --field-selector reason=PrecheckFailed
```

Validate admission annotations on a new pod:

```bash
kubectl get pod <pod-name> -n <namespace> -o go-template='{{range $k,$v := .metadata.annotations}}{{printf "%s\n" $k}}{{end}}' | grep -E 'rightsizing\\.kubex\\.ai/|automation-webhook\\.kubex\\.ai/pod-rightsizing-info'
```

Validate pod events:

```bash
kubectl get events --sort-by=.lastTimestamp | grep -E 'PolicyEvaluation|ResizeCompleted'
```

Validate controller summary logs:

```bash
kubectl logs -n kubex -l control-plane=controller-manager -c manager --since=10m | grep 'rightsizing summary'
```

Look for results such as `RESIZED`, `EVICTED`, `BLOCKED_RETRYING`, or `BLOCKED`.

## Apply Configuration Updates

Re-apply chart changes with:

```bash
helm upgrade --install kubex-automation-engine kubex/kubex-automation-engine \
  --namespace kubex \
  --create-namespace \
  -f charts/kubex-automation-engine/kubex-automation-values.yaml
```

## Uninstall

Use this sequence when you want to remove the controller without leaving policy or strategy resources stuck in `Terminating`.

### Remove externally managed CRs first

If you manage policies and strategies outside Helm, first request deletion of those CRs before uninstalling the chart so the running controller can process their cleanup logic.

This matters most for `ProactivePolicy` and `ClusterProactivePolicy` resources. Deleting them while the controller is still running gives the controller a chance to remove Kubex annotations it previously placed on workloads.

```bash
kubectl delete proactivepolicy,clusterproactivepolicy,staticpolicy,clusterstaticpolicy -A --all
kubectl delete automationstrategy,clusterautomationstrategy -A --all
```

Wait for those resources to disappear before uninstalling Helm release:

```bash
kubectl get proactivepolicy,clusterproactivepolicy,staticpolicy,clusterstaticpolicy,automationstrategy,clusterautomationstrategy -A
```

### Manually remove finalizers from external CRs only if deletion is stuck

The chart's pre-delete hook removes finalizers from Helm-managed `ClusterProactivePolicy` and `ClusterAutomationStrategy` resources so `helm uninstall` can complete while the controller is shutting down.

CRs managed outside Helm are not part of that hook. Do not clear finalizers before attempting deletion, because that can bypass controller cleanup. Only if a policy or strategy CR stays in `Terminating` after the delete step above should you manually clear its finalizers, and you should do that before `helm uninstall`:

```bash
for resource in \
  proactivepolicies \
  clusterproactivepolicies \
  staticpolicies \
  clusterstaticpolicies \
  automationstrategies \
  clusterautomationstrategies; do
  kubectl get "${resource}" --all-namespaces \
    -o 'go-template={{range .items}}{{.metadata.namespace}}{{"\t"}}{{.metadata.name}}{{"\n"}}{{end}}' | \
  while IFS=$(printf '\t') read -r namespace name; do
    [ -n "${name}" ] || continue
    if [ -n "${namespace}" ]; then
      kubectl patch "${resource}" "${name}" -n "${namespace}" --type=merge -p '{"metadata":{"finalizers":[]}}'
    else
      kubectl patch "${resource}" "${name}" --type=merge -p '{"metadata":{"finalizers":[]}}'
    fi
  done
done
```

Recheck until no policy or strategy CRs remain:

```bash
kubectl get proactivepolicy,clusterproactivepolicy,staticpolicy,clusterstaticpolicy,automationstrategy,clusterautomationstrategy -A
```

### Uninstall the Helm releases

After external CR cleanup is complete, remove the controller chart:

```bash
helm uninstall kubex-automation-engine --namespace kubex
```

If you also want to remove the CRDs from the cluster, uninstall the CRD chart after all custom resources are gone:

```bash
helm uninstall kubex-crds --namespace kubex
```

## Next Steps

- Review [Configuration Reference](./Configuration-Reference.md) for Helm keys and generated CRs
- Review [Policy Configuration](./Policy-Configuration.md) for strategy and scope design
- Review [Safety Controls](./Safety-Controls.md) for webhook health gating, pause controls, freshness checks, and execution-time safety filters
- Review [Troubleshooting](./Troubleshooting.md) if rightsizing is selected but not applied
- Use externally managed CRs for `StaticPolicy` and `ClusterStaticPolicy` until Helm-managed generation is added for those resource types
