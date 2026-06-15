# Migrating from Helm-Managed Configuration

This guide is for users migrating from the previous Kubex Automation Controller, where automation behavior was driven entirely from Helm values.

## Overview

The previous automation controller configuration model managed all automation behavior through Helm values, with the chart directly creating `ClusterAutomationStrategy` and `ClusterProactivePolicy` resources from those values.

The current approach separates concerns:
- **Helm chart**: Installs and operates the controller
- **Strategy and Policy CRs**: Managed externally via `kubectl`, GitOps, or other workflows

This separation provides several benefits:
- Strategy and policy configurations can evolve independently of chart upgrades
- No need to run `helm upgrade` to change automation behavior
- Better integration with GitOps workflows
- Clearer separation between infrastructure (controller) and configuration (policies)

## Migration Path

### Option 1: Transition to External CR Management (Recommended)

This is the recommended path for long-term maintainability.

**Step 1**: Extract your current Helm-managed configuration

If your current `values.yaml` contains `scope` and `policy.policies` sections like this:

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
      allowedPodOwners: "Deployment,StatefulSet,CronJob,Rollout,Job,StrimziPodSet"
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

**Step 2**: Convert to standalone CR manifests

Create equivalent `ClusterAutomationStrategy` and `ClusterProactivePolicy` resources:

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterAutomationStrategy
metadata:
  name: base-optimization
spec:
  allowedPodOwners:
    - Deployment
    - StatefulSet
    - CronJob
    - Rollout
    - Job
    - StrimziPodSet
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
---
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterProactivePolicy
metadata:
  name: team-a
spec:
  scope:
    namespaceSelector:
      operator: In
      values:
        - team-a
    podLabelSelectors:
      - key: app
        operator: In
        values:
          - demo
  automationStrategyRef:
    name: base-optimization
```

**Step 3**: Apply the CR manifests

```bash
kubectl apply -f automation-config.yaml
```

**Step 4**: Remove `scope` and `policy` sections from your Helm values

Update your `values.yaml` to remove the `scope` and `policy.policies` sections, keeping only the controller configuration (credentials, resource sizing, etc.).

**Step 5**: Upgrade the Helm release

```bash
helm upgrade kubex-automation-engine kubex/kubex-automation-engine \
  --namespace kubex \
  -f kubex-automation-values.yaml
```

The Helm-managed `ClusterAutomationStrategy` and `ClusterProactivePolicy` resources will be removed, but your externally-managed CRs will continue to function.

### Option 2: Continue with Helm-Managed Configuration

If you prefer to continue managing automation configuration through Helm values, you can do so. This path is provided for backward compatibility.

**When to use this option**:
- You have established Helm-based workflows that are difficult to change
- Your automation configuration changes infrequently and aligns with chart upgrade cycles
- You prefer consolidating all configuration in a single values file

**How it works**:

Define both `policy` and `scope` in your Helm values file:

```yaml
scope:
  - name: team-a
    policy: base-optimization
    namespaces:
      operator: In
      values:
        - team-a

policy:
  defaultPolicy: base-optimization
  policies:
    base-optimization:
      enablement:
        cpu:
          request:
            downsize: true
            upsize: true
        memory:
          request:
            downsize: true
            upsize: true
      inPlaceResize:
        enabled: true
      podEviction:
        enabled: true
```

Apply changes with:

```bash
helm upgrade kubex-automation-engine kubex/kubex-automation-engine \
  --namespace kubex \
  -f kubex-automation-values.yaml
```

Helm will render the corresponding `ClusterAutomationStrategy` and `ClusterProactivePolicy` resources from these values.

**Limitations**:
- Changing automation behavior requires a Helm upgrade
- Cannot use namespaced `AutomationStrategy` or `ProactivePolicy` resources
- `StaticPolicy` and `ClusterStaticPolicy` must still be managed externally

## Field Mapping Reference

When converting from Helm values to CRs, use this mapping:

| Helm Values Path | CR Field Path |
|-----------------|---------------|
| `policy.policies.<name>` | `ClusterAutomationStrategy.spec` |
| `scope[].name` | `ClusterProactivePolicy.metadata.name` |
| `scope[].policy` | `ClusterProactivePolicy.spec.automationStrategyRef.name` |
| `scope[].namespaces` | `ClusterProactivePolicy.spec.scope.namespaceSelector` |
| `scope[].podLabels` | `ClusterProactivePolicy.spec.scope.podLabelSelectors` |

## Next Steps

After migrating, see:
- [Automation Strategies](./Automation-Strategies.md) for strategy configuration details
- [Cluster Automation Strategies](./Cluster-Automation-Strategies.md) for cluster-scoped strategy configuration
- [Proactive Policies](./Proactive-Policies.md) for recommendation-driven policy configuration
- [Cluster Proactive Policies](./Cluster-Proactive-Policies.md) for cluster-wide policy configuration
- [Policy Configuration](./Policy-Configuration.md) for the overall strategy and policy model
