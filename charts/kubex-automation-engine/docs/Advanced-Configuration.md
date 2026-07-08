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

Use pause annotations to temporarily or permanently block automation.

Pod-scoped whole-pod pause:

- `rightsizing.kubex.ai/pause-until: <RFC3339|infinite>`
- `rightsizing.kubex.ai/pause-reason: <string>`

Container-scoped skip:

- `rightsizing.kubex.ai/skip-containers: "app,sidecar"`

Supported values for every `pause-until` key:

- RFC3339 timestamp
- `infinite`

Pod example:

```yaml
spec:
  template:
    metadata:
      annotations:
        rightsizing.kubex.ai/pause-until: "2026-04-01T00:00:00Z"
        rightsizing.kubex.ai/pause-reason: "maintenance window"
```

Container example:

```yaml
spec:
  template:
    metadata:
      annotations:
        rightsizing.kubex.ai/skip-containers: "app,sidecar"
```

Namespace example:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: payments
  annotations:
    rightsizing.kubex.ai/pause-until: "infinite"
    rightsizing.kubex.ai/pause-reason: "quarter-end freeze"
```

Behavior:

- pod-level `rightsizing.kubex.ai/pause-until` blocks whole pod and appears in `rightsizing summary.failedChecks` as `pause-active`
- `rightsizing.kubex.ai/skip-containers` prunes only matching container actions and appears in `rightsizing summary.appliedFilters` as `container-skip-active`
- sibling container actions still proceed when only one container is skipped
- pod annotation key beats owner annotation; no merge across pod and owners
- empty pod `skip-containers` value means skip none and disables owner fallback for that pod
- nearest supported owner with non-empty annotation wins when pod key is absent; no merge across multiple owners
- empty owner `skip-containers` values are ignored
- new pods do not inherit `skip-containers`; it is resolved directly from pod or owner at evaluation time
- existing owned pods are not reconciled to copy `skip-containers`
- pods in paused namespace are skipped even when pod itself has no pause annotation
- namespace pause annotations are evaluated at runtime only and are not copied onto pods
- namespace pause supports only pod-scoped keys
- webhook mutation skips whole pod only for pod-level or namespace-level pauses; `skip-containers` still allows non-skipped sibling mutations
- controller-side proactive execution skips whole pod only for pod-level or namespace-level pauses; `skip-containers` filters matching actions only
- time-based pauses automatically resume after expiration

Notes:

- pod-local pause annotations are still supported
- `skip-containers` can be set on pod or supported workload owner, but is not propagated or stored as inherited control state
- namespace-local pause annotations use same `rightsizing.kubex.ai/pause-reason` message format in `rightsizing summary` failed checks
- when pause annotation was inherited from workload owner, controller tracks internal inheritance state so it can safely remove inherited value later
- if pause annotation exists only on pod and was not inherited, controller treats it as pod-local and does not remove it during workload reconciliation

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
