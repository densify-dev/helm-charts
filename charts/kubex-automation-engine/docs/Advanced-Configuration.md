# Advanced Configuration Guide

This guide covers the operating model behind the new controller architecture and the most important advanced controls.

# Quick Links

- [Advanced Configuration Guide](#advanced-configuration-guide)
- [Quick Links](#quick-links)
  - [Global Configuration](#global-configuration)
  - [Pause Controls](#pause-controls)
  - [Safety Controls](#safety-controls)
  - [Execution Paths](#execution-paths)
  - [Backward Compatibility and Migration](#backward-compatibility-and-migration)

---

## Global Configuration

`GlobalConfiguration` controls cluster-wide behavior:

- recommendation refresh cadence
- rescan cadence
- webhook probe health thresholds
- protected namespace patterns
- global automation enablement

Use [Global Configuration Reference](./Global-Configuration.md) for the field-by-field reference and Helm mapping.

Example:

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: GlobalConfiguration
metadata:
  name: global-config
spec:
  recommendationReloadInterval: 1h
  rescanInterval: 6h
  mutationLogInterval: 5m
  kubexAPIRequestTimeout: 30s
  automationEnabled: true
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

## Pause Controls

Use the `rightsizing.kubex.ai/pause-until` annotation to temporarily or permanently block automation for a pod template.

Supported values:

- RFC3339 timestamp
- `infinite`

Example:

```yaml
spec:
  template:
    metadata:
      annotations:
        rightsizing.kubex.ai/pause-until: "2026-04-01T00:00:00Z"
```

Behavior:

- webhook mutation skips paused pods
- controller-side proactive execution skips paused pods
- time-based pauses automatically resume after expiration

## Safety Controls

Use [Safety Controls](./Safety-Controls.md) for the detailed reference of runtime pre-checks, action filters, evaluation order, and interpretation of `failedChecks` and `appliedFilters`.

## Execution Paths

The controller uses this execution order:

1. Build a candidate plan from the selected recommendation and policy.
2. Apply strategy enablement rules.
3. Apply safety checks and filters.
4. Execute in-place resize if enabled and supported.
5. Fall back to eviction if allowed.

If all candidate actions are filtered out, no resize is executed.

## Backward Compatibility and Migration

Existing `deployment.controllerEnv` values continue to work for supported settings. The chart maps them into `GlobalConfiguration` fields where possible, so upgrades do not require an immediate rewrite of your values file.

Typical migration path:

1. Keep existing values and upgrade the chart.
2. Verify generated `GlobalConfiguration` and any Helm-managed CRs.
3. Move environment-variable-based settings into `globalConfiguration`, `scope`, and `policy.policies`.
4. Adopt manual CRs only when you need the full CRD surface area.
