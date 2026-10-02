# Multi-policy container rightsizing

NOTE: The opt-in feature described in this document is considered stable and will eventually become the default behavior in a future release.

## What this solves

By default, the Kubex Automation Engine only applies one single policy per type on a whole Pod. For example, having 2 different `ProactivePolicy` that target the same pod will result in the one with the largest weight to be applied to the whole pod. This means that targeting the same pod using different policies is not possible using the current default behavior. 

Some examples of where the current behavior falls short:
- Having a ProactivePolicy that resizes CPU and memory for a whole namespace but wanting a ProactivePolicy that only resizes CPU for all Istio sidecar containers.
- Allowing in-place resizing only for some containers of a pod, requiring eviction for others.
- Using a policy to ignore a sidecar container across all of a namespace while still rightsizing other containers via another policy.

Use this when you want separate policies to manage those containers without one policy excluding the other.

## Example usage

### Enabling the feature

The setting to enable this feature defaults to `false`. For Helm, set the value and upgrade the release:

```yaml
globalConfiguration:
  multiPolicyContainerRightsizingEnabled: true
```

### Complete example

A Deployment in namespace `team-a` has the label `app: storefront` and two containers, `app` and `metrics`. The following strategies and policies manage these containers separately when the flag is enabled:

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: AutomationStrategy
metadata:
  name: app-balanced
  namespace: team-a
spec:
  enablement:
    cpu:
      requests:
        downsize: true
        upsize: true
      limits:
        downsize: true
        upsize: true
    memory:
      requests:
        downsize: true
        upsize: true
      limits:
        downsize: true
        upsize: true
  inPlaceResize:
    enabled: true
    containerRestart: false
  podEviction:
    enabled: true
---
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: AutomationStrategy
metadata:
  name: metrics-conservative
  namespace: team-a
spec:
  enablement:
    cpu:
      requests:
        downsize: true
        upsize: true
      limits:
        downsize: true
        upsize: true
    memory:
      requests:
        downsize: false
        upsize: false
        setFromUnspecified: false
      limits:
        downsize: false
        upsize: false
        setFromUnspecified: false
  inPlaceResize:
    enabled: true
    containerRestart: false
  podEviction:
    enabled: true
---
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ProactivePolicy
metadata:
  name: app-sizing
  namespace: team-a
spec:
  scope:
    labelSelector:
      matchLabels:
        app: storefront
    workloadTypes: [Deployment]
    containers: [app]
  automationStrategyRef:
    name: app-balanced
  weight: 100
---
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ProactivePolicy
metadata:
  name: metrics-sizing
  namespace: team-a
spec:
  scope:
    labelSelector:
      matchLabels:
        app: storefront
    workloadTypes: [Deployment]
    containers: [metrics]
  automationStrategyRef:
    name: metrics-conservative
  weight: 50
```

`app-balanced` allows CPU and memory upsizing and downsizing. `metrics-conservative` rightsizes only the sidecar's CPU. It leaves memory requests and limits untouched on the sidecar, including when they are unset. Both strategies allow in-place resize without container restart and eviction fallback, so their allowed resize methods overlap. See [Automation Strategies](./Automation-Strategies.md) for strategy configuration.

#### How the flag changes this example

With the flag disabled, each policy filters its recommendation to its scoped container, but both collide with each-other. Only one policy contributes to the workload: `app-sizing`, with weight 100, wins over `metrics-sizing`, with weight 50. Only `app` receives recommendations from these policies; `metrics-sizing` stays untouched.

With `multiPolicyContainerRightsizingEnabled: true`, each policies stop colliding and are marged. Resource candidates are looked at independently for each container, request or limit, and resource. Both policies can contribute: `app-sizing` rightsizes `app` CPU and memory using `app-balanced`, and `metrics-sizing` rightsizes only `metrics` CPU using `metrics-conservative`. Compatible resize methods and safety checks still govern execution of the combined plan.

If policies target the same container and resource, the existing precedence mechanism decides which candidate wins. See [Policy Evaluation](./Policy-Evaluation.md#multi-policy-composition) for the ranking order. This setting does not change policy-type priorities or make runtime-hook policies merge.

## Upgrade and rollback warning

Enabling or disabling this setting triggers a rescan of resource policies. Existing workload annotations are rewritten gradually as policies reconcile, not all at once. Expect a temporary mix of fixed and policy-owned hashed keys across the cluster, both formats are accepted during the transition.

A selected recommendation whose key changes restarts rollback monitoring, even when its resource values are unchanged. Existing rollback state is not migrated. Monitor workload events and controller logs after either change. Disabling the setting also restores single-policy selection within each resource policy kind, so containers previously managed by other same-kind policies may no longer receive their recommendations.

## Annotation keys when the setting changes

With the setting disabled, resource policies use fixed request and limit keys. When enabled, each policy uses hashed keys that include its policy identity, such as `<prefix>/h<digest>-desired-resource-requests`.

