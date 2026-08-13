# Advanced Configuration Guide

This guide covers the operating model behind the new controller architecture and the most important advanced controls.

# Quick Links

- [Advanced Configuration Guide](#advanced-configuration-guide)
- [Quick Links](#quick-links)
  - [Global Configuration](#global-configuration)
  - [Pause Controls](#pause-controls)
  - [Understanding Pod Automation Constraints](#understanding-pod-automation-constraints)
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
  kubexAPIRequestTimeout: 60s
  automationEnabled: true
  respectKubexAutomation: true
  protectedNamespacePatterns:
    - "kube-*"
    - "openshift-*"
    - "gmp-*"
    - "kubex-*"
  webhookHealth:
    failureThreshold: 2
    successThreshold: 3
    transitionCheckInterval: 10s
```

## Pause Controls

Use pause annotations to control when and how automation applies to your workloads.

### Overview

There are two types of pause controls with different behaviors:

| Annotation | Scope | Effect | Appears In |
|------------|-------|--------|------------|
| `rightsizing.kubex.ai/pause-until` | Whole pod | Blocks **all** automation for the pod | `failedChecks` as `pause-active` |
| `rightsizing.kubex.ai/skip-containers` | Specific containers | Removes actions **only** for named containers; other containers still resized | `appliedFilters` as `container-skip-active` |

**Key difference**: `pause-until` is an emergency stop for the entire pod. `skip-containers` is a surgical filter for individual containers.

### `pause-until` - Block Entire Pod

Use `pause-until` to completely stop all automation for a pod.

**Supported values:**
- RFC3339 timestamp (e.g., `2026-04-01T00:00:00Z`) - pauses until that time
- `infinite` - pauses indefinitely

**Where you can set it:**
- Pod template (in Deployment, StatefulSet, etc.)
- Namespace (blocks all pods in that namespace)

**Example: Pause pod during maintenance**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    metadata:
      annotations:
        rightsizing.kubex.ai/pause-until: "2026-04-01T00:00:00Z"
        rightsizing.kubex.ai/pause-reason: "maintenance window"
```

**Example: Pause entire namespace**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: payments
  annotations:
    rightsizing.kubex.ai/pause-until: "infinite"
    rightsizing.kubex.ai/pause-reason: "quarter-end freeze"
```

**Behavior:**
- Blocks **both** webhook mutations and controller-side proactive execution for the entire pod
- Time-based pauses automatically resume after expiration
- Namespace pauses affect all pods in that namespace, even if the pod itself has no annotation
- `pause-reason` is optional but recommended for clarity in logs and events

### `skip-containers` - Skip Specific Containers

Use `skip-containers` to prevent automation for specific containers while allowing other containers in the same pod to be resized.

**Format:** Comma-separated list of container names (e.g., `"app,sidecar"`)

**Where you can set it:**
- Pod template (in Deployment, StatefulSet, etc.)
- Workload owner (Deployment, StatefulSet, etc.)
- **NOT supported** on Namespace

**Example: Skip specific containers**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    metadata:
      annotations:
        rightsizing.kubex.ai/skip-containers: "app,sidecar"
    spec:
      containers:
      - name: app          # ← Will NOT be resized
      - name: sidecar      # ← Will NOT be resized
      - name: proxy        # ← Will still be resized
```

**Behavior:**
- Only removes actions for the named containers
- Other containers in the same pod continue to be resized normally
- Works with both webhook mutations and controller-side proactive execution
- Does **not** block the entire pod - only filters specific container actions

### How They Work Together

If both annotations are present, `pause-until` takes precedence because it's evaluated first:

```yaml
annotations:
  rightsizing.kubex.ai/pause-until: "infinite"      # ← Checked first (blocks whole pod)
  rightsizing.kubex.ai/skip-containers: "app"       # ← Never evaluated (pod already blocked)
```

**Result:** Entire pod is blocked. The `skip-containers` annotation is ignored.

If only `skip-containers` is present:

```yaml
annotations:
  rightsizing.kubex.ai/skip-containers: "app,sidecar"
```

**Result:** Pod is processed normally, but actions for `app` and `sidecar` containers are removed. Other containers are still resized.

### Resolution Rules

#### `pause-until` Resolution

1. **Namespace-level pause** - Blocks all pods in the namespace
2. **Pod-level pause** - Blocks that specific pod
3. **Owner-level pause** (Deployment, etc.) - Controller copies to owned pods and tracks inheritance

**Pod annotations override everything:**
- If a pod has `pause-until`, it uses that value (even if namespace or owner also has it)
- If the annotation was inherited from an owner, the controller manages its lifecycle and can remove it later
- If you manually set `pause-until` directly on a pod (not via owner), the controller treats it as user-managed and won't remove it

#### `skip-containers` Resolution

The controller uses this priority order to determine which containers to skip:

**1. Pod annotation (if present) - Always wins**

The behavior depends on whether the annotation exists and its value:

- **Pod has `skip-containers: "app,sidecar"`** → Skip those containers (uses pod value)
- **Pod has `skip-containers: ""`** (empty string) → Skip NO containers and stop looking (explicit override)
- **Pod has no `skip-containers` annotation** → Continue to step 2 (check owners)

**2. Owner fallback (only if pod has NO annotation)**

If the pod template has no `skip-containers` annotation at all, the controller checks workload owners (Deployment, StatefulSet, etc.):

- First owner with a **non-empty** value wins
- Owners with **empty values** (`skip-containers: ""`) are **ignored** and the search continues
- No merging across multiple owners

**The key distinction:**
- **Missing annotation on pod** = "I don't care, check my owner"
- **Empty annotation on pod** (`skip-containers: ""`) = "I explicitly want to skip nothing, don't check my owner"
- **Empty annotation on owner** (`skip-containers: ""`) = "Ignore this owner, keep searching for another owner"

**Key points:**
- `skip-containers` is **resolved at evaluation time** - it's not copied to pods
- New pods do not inherit `skip-containers` - it's looked up each time from pod or owner
- Namespace-level `skip-containers` is **not supported**

### Examples

**Example 1: Multi-container pod with selective skip**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  template:
    metadata:
      annotations:
        rightsizing.kubex.ai/skip-containers: "nginx,redis"
    spec:
      containers:
      - name: nginx        # Skipped
      - name: redis        # Skipped
      - name: app          # Still resized
      - name: metrics      # Still resized
```

**Example 2: Pod overrides owner**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  annotations:
    rightsizing.kubex.ai/skip-containers: "app,sidecar"  # Owner wants to skip these
spec:
  template:
    metadata:
      annotations:
        rightsizing.kubex.ai/skip-containers: ""  # Pod explicitly skips NONE
    spec:
      containers:
      - name: app          # Will be resized (pod annotation wins)
      - name: sidecar      # Will be resized (pod annotation wins)
```

**Example 3: Empty owner value vs missing pod annotation**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  annotations:
    rightsizing.kubex.ai/skip-containers: ""  # Empty owner value - ignored
spec:
  template:
    metadata:
      # Pod has NO skip-containers annotation (missing entirely)
    spec:
      containers:
      - name: app          # Will be resized
      - name: sidecar      # Will be resized
```
**Why?** Pod has no annotation (missing), so controller checks owner. Owner has empty value, which is ignored. No other owners found, so nothing is skipped.

**Contrast with Example 2:** If the pod had `skip-containers: ""` (empty but present), all containers would still be resized, but for a different reason - the pod explicitly says "skip nothing" and blocks owner fallback.

**Example 4: Combined pause and skip (pause wins)**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  annotations:
    rightsizing.kubex.ai/pause-until: "infinite"  # Namespace-level pause
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: production
spec:
  template:
    metadata:
      annotations:
        rightsizing.kubex.ai/skip-containers: "sidecar"  # Never evaluated
    spec:
      containers:
      - name: app          # Blocked by namespace pause
      - name: sidecar      # Blocked by namespace pause
```

### Troubleshooting

**Where annotations appear in summaries:**
- `pause-until` failures → `rightsizing summary.failedChecks` with name `pause-active`
- `skip-containers` filters → `rightsizing summary.appliedFilters` with name `container-skip-active`

**Check if a pod is paused:**
```bash
kubectl get pod <pod-name> -o yaml | grep -A2 "pause-until"
kubectl get namespace <namespace> -o yaml | grep -A2 "pause-until"
```

**Check which containers are skipped:**
```bash
kubectl get deployment <name> -o yaml | grep "skip-containers"
kubectl get pod <pod-name> -o yaml | grep "skip-containers"
```

## Understanding Pod Automation Constraints

`rightsizing.kubex.ai/automation-constraints` explains why Kubex could not apply all or part of a rightsizing recommendation to a Pod. Check this annotation on the Pod when an expected resize does not happen.

Each entry includes:

- `reason`: short explanation of what prevented automation, such as `hpa-resource-managed` or `namespace-protected`
- `targets`: containers and resources affected by that reason

A target can include:

- `container`: container name
- `resource`: `cpu` or `memory`
- `usage`: whether the recommendation concerns `requests` or `limits`

For example, this entry means Kubex could not change the `app` container's CPU requests because an HPA manages that resource:

```json
[
  {
    "reason": "hpa-resource-managed",
    "targets": [
      {"container": "app", "resource": "cpu", "usage": "requests"}
    ]
  }
]
```

An empty `targets` list means the reason applies to the whole Pod, rather than a specific container or resource. For example, a protected namespace prevents automation for the entire Pod:

```json
[
  {
    "reason": "namespace-protected",
    "targets": []
  }
]
```

The annotation shows the latest situation. It updates when conditions change and disappears when nothing is limiting automation.

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
