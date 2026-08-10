# Troubleshooting Guide

This guide helps you diagnose and resolve issues when rightsizing does not happen as expected.

**Prerequisites**: Many diagnostic commands in this guide use `jq` for JSON parsing. Install with: `apt-get install jq` (Debian/Ubuntu), `brew install jq` (macOS), or `yum install jq` (RHEL/CentOS).

## Troubleshooting Approach

The controller provides multiple levels of diagnostic information. Use them in this order:

1. **Start with annotations** - Check the `automation-constraints` annotation on the pod to see blockers and filters
2. **Check summary logs** - View `rightsizing summary` logs to understand evaluation outcomes
3. **Review events** - Look for `PrecheckFailed` or policy evaluation events for patterns
4. **Verify configuration** - Check GlobalConfiguration, policies, and strategies for misconfigurations

**When to use what:**
- **Annotations** (`automation-constraints`, `rollback-state`) - Best for understanding why a specific pod is blocked right now
- **Summary logs** - Best for seeing evaluation history and understanding what the controller attempted
- **Events** - Best for identifying patterns across multiple pods or tracking timeline of actions
- **Debug logging** - Only needed for controller internal issues or when requested by support

Most issues can be diagnosed using annotations and summary logs without enabling debug logging.

## Quick Links

- [Quick Troubleshooting Decision Tree](#quick-troubleshooting-decision-tree) ⭐ Start here
- [Understanding Annotations for Troubleshooting](#understanding-annotations-for-troubleshooting)
- [1. Interpret Rightsizing Summary Logs](#1-interpret-rightsizing-summary-logs)
- [2. Check Global Health](#2-check-global-health)
- [3. Check Policy and Strategy Resolution](#3-check-policy-and-strategy-resolution)
- [4. Check Runtime Events](#4-check-runtime-events)
- [5. Common Blockers](#5-common-blockers)
- [6. Verify Webhook Registration](#6-verify-webhook-registration)
- [Quick Diagnostic Commands](#quick-diagnostic-commands)
- [Enable Debug Logging (Rarely Needed)](#enable-debug-logging-rarely-needed)

For a consolidated map of the controller's safety gates, see [Safety Controls](./Safety-Controls.md).

For annotation configuration details, see [Advanced Configuration Guide](./Advanced-Configuration.md#pause-controls).

## Quick Troubleshooting Decision Tree

**Automation not happening?** Follow this path:

1. **Check `automation-constraints` annotation on the pod** (easiest & fastest) → See [Understanding Annotations](#understanding-annotations-for-troubleshooting)
   ```bash
   kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.metadata.annotations.rightsizing\.kubex\.ai/automation-constraints}' | jq .
   ```
   - Has `BLOCKER` reasons? → Jump to that specific blocker in [Common Blockers](#5-common-blockers)
   - No annotation at all? → Check if policy matches the workload in [Check Policy and Strategy Resolution](#3-check-policy-and-strategy-resolution)

   **Alternative**: Check `rightsizing summary` logs for evaluation history → See [Interpret Rightsizing Summary Logs](#1-interpret-rightsizing-summary-logs)
   - Logs show `BLOCKED`? → Check `failedChecks` array for blocker names
   - Logs show `SKIPPED`? → All actions were filtered or no recommendations available
   - No logs for your pod? → Policy may not match, or controller may not be running
   - **When to use logs**: When you need historical context or the pod no longer exists

2. **Check if recommendations exist on the pod**
   ```bash
   kubectl get pod <pod-name> -n <namespace> -o json | jq '.metadata.annotations | with_entries(select(.key | contains("desired-resource")))'
   ```
   - No recommendations? → Verify policy configuration and recommendation sync

3. **Still stuck?** 
   - Verify global health in [Check Global Health](#2-check-global-health)
   - Check runtime events for patterns in [Check Runtime Events](#4-check-runtime-events)
   - Collect support information using [Quick Diagnostic Commands](#quick-diagnostic-commands)

**Everything looks fine but nothing happens?** Common causes:
- Recommendations match current state (no drift to correct)
- Pod resources already match desired values
- All containers are filtered by `skip-containers` annotation
- Policy evaluation hasn't run yet (check evaluation interval in AutomationStrategy)

---

## Understanding Annotations for Troubleshooting

When troubleshooting, you'll encounter annotations on both **pod owners** (Deployment, StatefulSet, etc.) and **pods** themselves. Understanding where annotations appear and what they mean is essential for diagnosis.

### Pod Owner vs Pod: What's the Difference?

**Pod Owner** = The workload resource that creates and manages pods:
- Deployment, StatefulSet, DaemonSet, Job, CronJob, ReplicaSet, StrimziPodSet

**Pod** = The actual running pod instance created by the owner

### Which Annotations Appear Where?

| Annotation | Found On Pod Owner | Found On Pod |
|------------|-------------------|--------------|
| `rightsizing.kubex.ai/pause-until` | ✅ You set here | ✅ Inherited or set directly |
| `rightsizing.kubex.ai/skip-containers` | ✅ You set here | ✅ Inherited or set directly |
| `*.rightsizing.kubex.ai/desired-resource-requests` | ✅ For static policies | ✅ Always present |
| `*.rightsizing.kubex.ai/desired-resource-limits` | ✅ For static policies | ✅ Always present |
| `rightsizing.kubex.ai/automation-constraints` | ❌ Never | ✅ On evaluated pods |
| `rightsizing.kubex.ai/rollback-state` | ✅ Only on owner | ❌ Never on pods |
| `rightsizing.kubex.ai/inherited-control-state` | ❌ Never | ✅ When inherited |

**Notes:**
- **pause-until & skip-containers**: Owner annotations are automatically copied to pods. Check `inherited-control-state` to see if managed by controller.
- **desired-resource-requests & limits**: Recommendations written to pods. Static policies also write to owners. Policy prefix indicates source.
- **automation-constraints**: **Most important for troubleshooting** - shows why automation is blocked or what filters are active. Contains `reasons[]` array.
- **rollback-state**: Rollback tracking happens at owner level only. Shows monitoring/backoff state.
- **inherited-control-state**: Indicates pause/skip was inherited from owner and is managed by controller.

### Interpreting Control Annotations (Pause & Skip)

When you see `rightsizing.kubex.ai/pause-until` or `rightsizing.kubex.ai/skip-containers`:

#### On Pod Owner (Deployment, StatefulSet, etc.)
```bash
kubectl get deployment my-app -n production -o yaml
```
```yaml
spec:
  template:
    metadata:
      annotations:
        rightsizing.kubex.ai/pause-until: "infinite"
```

**What this means**: You (or another user) set this on the owner. The controller will copy it to all pods managed by this owner.

#### On Pod
```bash
kubectl get pod my-app-abc123 -n production -o yaml
```
```yaml
metadata:
  annotations:
    rightsizing.kubex.ai/pause-until: "infinite"
    rightsizing.kubex.ai/inherited-control-state: "..."  # ← Key indicator
```

**Interpretation**: 
- **`inherited-control-state` present**: Pause was inherited from the owner. Controller manages this automatically and will remove it when you remove it from the owner.
- **`inherited-control-state` absent**: Pause was set directly on the pod (rare). Controller won't remove it automatically.

**Troubleshooting tip** - If a pause annotation isn't clearing when expected:
1. Check if it's still on the pod owner (Deployment, StatefulSet, etc.) - remove it there first
2. If pod has `inherited-control-state` annotation, removing from owner will automatically fix it
3. If no `inherited-control-state`, the annotation was set directly on the pod - remove it manually from the pod

### Interpreting Recommendation Annotations

Recommendation annotations use **policy prefixes** to indicate their source:

| Annotation Pattern | What It Means |
|-------------------|---------------|
| `static.rightsizing.kubex.ai/desired-resource-requests` | From StaticPolicy (namespace-scoped) - recommendations are statically defined in the policy |
| `cwstatic.rightsizing.kubex.ai/desired-resource-requests` | From ClusterStaticPolicy (cluster-scoped) - cluster-wide static recommendations |
| `proactive.rightsizing.kubex.ai/desired-resource-requests` | From ProactivePolicy (namespace-scoped) - recommendations from Kubex platform analysis |
| `cwproactive.rightsizing.kubex.ai/desired-resource-requests` | From ClusterProactivePolicy (cluster-scoped) - cluster-wide proactive recommendations |
| `gpureactive.rightsizing.kubex.ai/desired-resource-requests` | From GPU reactive policies - GPU-specific recommendations |
| `rollbackpolicy.rightsizing.kubex.ai/desired-resource-requests` | From RollbackPolicy - controller is rolling back to these values |

**Naming convention**: 
- No prefix = namespace-scoped policy
- `cw` prefix (cluster-wide) = cluster-scoped policy
- Same applies to `desired-resource-limits` annotations

**Example on a pod:**
```bash
# View all recommendation annotations (requires jq - JSON processor tool)
kubectl get pod my-app-abc123 -o jsonpath='{.metadata.annotations}' | jq 'with_entries(select(.key | contains("desired-resource")))'
```

Output:
```json
{
  "proactive.rightsizing.kubex.ai/desired-resource-requests": "{\"app\":{\"cpu\":\"500m\",\"memory\":\"1Gi\"}}",
  "proactive.rightsizing.kubex.ai/desired-resource-limits": "{\"app\":{\"memory\":\"1Gi\"}}"
}
```

**Interpretation**: 
- A ProactivePolicy evaluated this pod and wants to set CPU to 500m and memory to 1Gi for the "app" container
- Memory limit is also being managed
- Missing annotations indicate either no policy matched the pod or recommendations haven't been generated

### Interpreting Automation State Annotation

The `rightsizing.kubex.ai/automation-constraints` annotation appears only on pods and is **the most important annotation for troubleshooting**. It shows why automation is blocked or what filters are applied:

```bash
# View automation constraints (requires jq)
kubectl get pod my-app-abc123 -o jsonpath='{.metadata.annotations.rightsizing\.kubex\.ai/automation-constraints}' | jq .
```

#### Annotation Format

The annotation is a JSON array where each entry represents a constraint with a `reason` code and a `targets` array specifying what is affected:

**Structure:**
```json
[
  {
    "reason": "reason-code",
    "targets": [
      {
        "container": "container-name",
        "resource": "cpu",
        "usage": "requests"
      }
    ]
  }
]
```

**Understanding `targets`:**

- **Empty array `[]`** = Global constraint affecting the entire pod
- **Non-empty array** = Constraint applies only to the specific container/resource/usage combinations listed

Common reason codes include:

- `hpa-resource-managed`
- `namespace-protected`
- `pause-active`
- `limit-range-violated`
- `resource-quota-exceeded`
- `automation-strategy-disabled`
- `scheduling-window-blocked`

**Example - HPA managing specific resources:**
```json
[
  {
    "reason": "hpa-resource-managed",
    "targets": [
      {
        "container": "app",
        "resource": "cpu",
        "usage": "limits"
      },
      {
        "container": "app",
        "resource": "cpu",
        "usage": "requests"
      }
    ]
  }
]
```
**What this means**: HPA is managing CPU requests and limits for the "app" container. Memory automation is unaffected since it's not in the targets list.

**Example - Pause active:**
```json
[
  {
    "reason": "pause-active",
    "targets": []
  }
]
```
**What this means**: Automation is paused for this pod. Empty targets indicates this blocks all automation. Check for `pause-until` annotation on the pod, pod owner, or namespace.

### Interpreting Rollback State (Pod Owner Only)

The `rollback-state` annotation appears only on pod owners and tracks rollback progress:

```bash
# View rollback state (requires jq)
kubectl get deployment my-app -o jsonpath='{.metadata.annotations.rightsizing\.kubex\.ai/rollback-state}' | jq .
```

**Key fields:**

| Field | What It Means |
|-------|---------------|
| `mode` | Current rollback phase: `monitoring`, `rollingBack`, `backingOff`, `backedOff`, `idle` |
| `startedAt` | When monitoring started |
| `rollbackStartedAt` | When rollback was triggered |
| `expiryAt` | When backoff period ends |
| `failureReason` | Why rollback was triggered (e.g., `pod-restart-rate-exceeded`) |

**Example:**
```json
{
  "mode": "backingOff",
  "failureReason": "pod-restart-rate-exceeded",
  "expiryAt": "2026-08-06T12:00:00Z"
}
```
**Interpretation**: Rollback triggered due to excessive pod restarts. Currently in backoff period. Automation will resume after expiry time.

For more details on rollback behavior, see [Rollback Documentation](./Rollback-Backoff.md).

---

## 1. Interpret Rightsizing Summary Logs

The controller logs a `rightsizing summary` for each evaluation. These logs are your primary diagnostic tool.

```bash
# View recent rightsizing evaluation summaries
kubectl logs -n kubex -l control-plane=controller-manager -c manager --since=10m | grep 'rightsizing summary'
```

### Key Log Fields

| Field | What It Tells You |
|-------|-------------------|
| `rightsizingResult` | Final outcome of the evaluation (see outcomes below) |
| `policy` | Which policy was evaluated (ProactivePolicy, StaticPolicy, etc.) |
| `failedChecks` | **Array of blockers** that prevented automation. Empty means no blockers. |
| `appliedFilters` | **Array of filters** that removed specific container actions. Empty means no filters applied. |
| `summary` | Container-by-container breakdown of what happened |

**Note**: The log format includes internal details like `INFO`/`BLOCKER` distinctions and full metadata. The `automation-constraints` annotation on pods uses a **simplified format** for easier troubleshooting. See [Interpreting Automation State Annotation](#interpreting-automation-state-annotation) for the annotation structure.

### Common Outcomes

| Result | Meaning | What Happened |
|--------|---------|---------------|
| `RESIZED` | ✅ Success | In-place resize was applied to the pod. Resources updated without restart. |
| `EVICTED` | ✅ Success | Eviction path was used. Pod was deleted and will be recreated with new resources. |
| `BLOCKED_RETRYING` | ⏸️ Temporary block | Blocked by a temporary condition (e.g., pod not ready). Will retry automatically. |
| `BLOCKED` | 🛑 Permanent block | Blocked or failed without retry. Check `failedChecks` to see why. |
| `SKIPPED` | ⏭️ Nothing to do | Nothing actionable remained after evaluation. May indicate filters removed all actions. |

### Example Log Analysis

**Example 1: Blocked by pause annotation**
```json
"rightsizingResult": "BLOCKED"
"failedChecks": ["pause-active"]
"summary": "automation paused by annotation"
```
**Action**: Check pod, pod owner, and namespace for `rightsizing.kubex.ai/pause-until` annotation.

**Example 2: Container filtered out**
```json
"rightsizingResult": "RESIZED"
"appliedFilters": ["container-skip-active"]
"summary": "resized 2 of 3 containers (1 skipped)"
```
**Action**: Check `rightsizing.kubex.ai/skip-containers` annotation. One container was skipped, but others were resized successfully.

**Example 3: Temporarily blocked**
```json
"rightsizingResult": "BLOCKED_RETRYING"
"failedChecks": ["pod-not-ready"]
"summary": "waiting for pod to become ready"
```
**Action**: Wait. Controller will retry automatically when pod becomes ready. This is normal during rollouts.

## 2. Check Global Health

The GlobalConfiguration resource controls cluster-wide automation behavior. Start here to rule out global issues.

```bash
# View global configuration details
kubectl get globalconfiguration global-config -o yaml
kubectl describe globalconfiguration global-config
```

**Expected output sections:**
- `spec.automationEnabled: true` - Global automation switch
- `status.conditions` - Should show `Ready` conditions
- `spec.protectedNamespacePatterns` - List of protected namespaces

### What to Check

| Setting | Expected Value | What If It's Wrong |
|---------|----------------|-------------------|
| `spec.automationEnabled` | `true` | **If `false`**: All automation is disabled cluster-wide. Set to `true` to enable. |
| Webhook health condition | `Ready` | **If not Ready**: Proactive automation may be paused. Check webhook probe configuration and logs. |
| `spec.protectedNamespacePatterns` | Should NOT match your target namespace | **If matched**: Your namespace is protected. Remove it from the patterns or use a different namespace. |
| Recommendation reload | Check status for errors | **If failing**: Controller cannot fetch recommendations from Kubex platform. Check API connectivity and credentials. |

### Common Issues

**Automation globally disabled**
```yaml
spec:
  automationEnabled: false  # ← This disables ALL automation
```
**Fix**: Set `automationEnabled: true`

**Namespace is protected**
```yaml
spec:
  protectedNamespacePatterns:
    - "kube-*"
    - "production-*"  # ← Your namespace might match this pattern
```
**Fix**: Remove the pattern or rename your namespace

**GlobalConfiguration not Ready**

**How to spot**: 
- Run `kubectl get globalconfiguration global-config` and look at the READY column. If it shows `False` or is missing, there's an issue.
- Controller logs will show error messages like:
  - `"pod admission webhook probe failed"` (webhook health issues)
  - `"failed to reload recommendations"` (recommendation sync failures)
  - Events will be emitted: `PodAdmissionWebhookUnhealthy`, `RecommendationReloadFailed`, or `ProposalReloadFailed`

```bash
kubectl get globalconfiguration global-config
# Example output showing not ready:
# NAME            READY   AGE
# global-config   False   5d
```

This happens when the controller detects a critical issue preventing safe operation. Common causes:
- **Webhook health check failing**: Probe pod cannot be created (often due to image policies). New pods won't get recommendations applied.
- **Recommendation sync failing**: Cannot connect to Kubex platform API. Proactive policies won't have fresh recommendations.
- **Controller not running**: Pod crashed or failed to start.

**Action**: Check `status.conditions` in GlobalConfiguration to identify which component failed, then check controller logs for details. If webhook health is failing, see [Webhook and System Blockers](#webhook-and-system-blockers).

### Important Notes

- **Webhook failures usually appear as missed mutations**, not rejected pod admissions. New pods will be created but won't have recommendations applied.
- **If webhook health becomes unhealthy, proactive automation may pause** until probe health recovers. This is a safety mechanism.
- **Validating webhook rejection behavior** depends on `webhook.failurePolicy` (defaults to `Ignore`), so failed webhook calls won't block pod creation.
- **If `POD_NAMESPACE` environment variable is missing** in a custom deployment, the controller will fail to start. This is rare unless you've modified the Helm chart.

## 3. Check Policy and Strategy Resolution

Policies (ProactivePolicy, StaticPolicy, etc.) define **what** to resize. AutomationStrategies define **how** to resize (in-place vs eviction, safety checks, etc.). If your policy references a strategy that doesn't exist or is invalid, automation won't work.

### Check Policies

```bash
# Namespace-scoped policies
kubectl describe proactivepolicy -A
kubectl describe staticpolicy -A

# Cluster-scoped policies
kubectl describe clusterproactivepolicy
kubectl describe clusterstaticpolicy
```

### Check Strategies

```bash
# Namespace-scoped strategies
kubectl describe automationstrategy -A

# Cluster-scoped strategies
kubectl describe clusterautomationstrategy
```

### What to Look For

**Status fields**:
- `resolvedStrategy` - Should show the strategy name if found
- `conditions` - Look for errors like `StrategyNotFound` or `InvalidReference`

**Events**:
- `StrategyResolved` - Good! Strategy was found and is valid
- `StrategyNotFound` - **Problem**: Referenced strategy doesn't exist
- `InvalidStrategyReference` - **Problem**: Strategy reference is malformed

### Common Issues

**Strategy not found**
```
Status:
  Conditions:
    Type: StrategyResolved
    Status: False
    Reason: StrategyNotFound
    Message: AutomationStrategy "my-strategy" not found in namespace "default"
```
**Fix**: Create the strategy or update the policy to reference an existing strategy.

**Invalid strategy reference**
```yaml
spec:
  automationStrategy:
    name: ""  # ← Empty name is invalid
    kind: "AutomationStrategy"
```
**Fix**: Provide a valid strategy name.

**Namespace vs Cluster scope mismatch**
- ProactivePolicy (namespace-scoped) can reference AutomationStrategy (namespace) or ClusterAutomationStrategy (cluster)
- ClusterProactivePolicy (cluster-scoped) can only reference ClusterAutomationStrategy (cluster)

## 4. Check Runtime Events

Kubernetes events provide a timeline of what the controller has done. Use these to see policy evaluation outcomes and identify patterns.

### Useful Event Queries

```bash
# Prechecks that failed (blockers)
kubectl get events -A --field-selector reason=PrecheckFailed

# Policies that were selected for evaluation
kubectl get events -A --field-selector reason=PolicyEvaluationSelected

# Policies that were skipped (no action needed)
kubectl get events -A --field-selector reason=PolicyEvaluationSkipped

# Successful in-place resizes
kubectl get events -A --field-selector reason=PolicyEvaluationInPlaceResize

# Successful eviction resizes
kubectl get events -A --field-selector reason=PolicyEvaluationEvictResize
```

### Interpreting Events

| Event Reason | What It Means | Action |
|--------------|---------------|--------|
| `PrecheckFailed` | Automation was blocked by a precheck (pause, HPA, etc.) | Check the event message for the specific blocker. Cross-reference with [Common Blockers](#5-common-blockers). |
| `PolicyEvaluationSelected` | A policy was selected and evaluated for this workload | Normal operation. Check if it resulted in resize or was blocked. |
| `PolicyEvaluationSkipped` | Policy evaluation was skipped (nothing to do) | May indicate no recommendations, or all actions were filtered out. |
| `PolicyEvaluationInPlaceResize` | In-place resize was successfully applied | ✅ Success! Pod resources were updated without restart. |
| `PolicyEvaluationEvictResize` | Eviction path was used to resize | ✅ Success! Pod was evicted and will be recreated with new resources. |

### Example: Finding Why Automation Is Blocked

```bash
kubectl get events -n production --field-selector reason=PrecheckFailed --sort-by='.lastTimestamp'
```

Output:
```
LAST SEEN   TYPE      REASON           OBJECT              MESSAGE
2m          Warning   PrecheckFailed   pod/my-app-abc123   automation paused by annotation
```

This tells you the pod is blocked by a pause annotation. Check the pod and its owner for `rightsizing.kubex.ai/pause-until`.

## 5. Common Blockers

Use the steps above to identify blockers, then consult this list for common causes and solutions. Blockers are grouped by frequency and impact.

### Annotation-Related Blockers (Very Common)

| Blocker | Where to Check | How to Fix |
|---------|----------------|------------|
| **Pause annotation active** (`pause-active` in `failedChecks`) | Pod annotation: `rightsizing.kubex.ai/pause-until`<br>Pod owner annotation (Deployment, StatefulSet, etc.)<br>Namespace annotation | Remove the annotation or wait for timestamp to expire. See [Pause Controls](./Advanced-Configuration.md#pause-controls). |
| **Container skipped** (`container-skip-active` in `appliedFilters`) | Pod annotation: `rightsizing.kubex.ai/skip-containers`<br>Pod owner annotation | Remove container name from list or remove annotation. Empty string `""` means skip none. |
| **Inherited pause not clearing** | Check both pod and pod owner annotations | Remove from pod owner (Deployment, etc.), not the pod. Controller manages inherited annotations. |

**Quick annotation lookup:**
```bash
# Check pause annotation on pod, owner, and namespace
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.metadata.annotations.rightsizing\.kubex\.ai/pause-until}'
kubectl get deployment <deployment-name> -n <namespace> -o jsonpath='{.spec.template.metadata.annotations.rightsizing\.kubex\.ai/pause-until}'
kubectl get namespace <namespace> -o jsonpath='{.metadata.annotations.rightsizing\.kubex\.ai/pause-until}'

# Check skip-containers annotation
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.metadata.annotations.rightsizing\.kubex\.ai/skip-containers}'
```

### Recommendation-Related Blockers (Common)

| Blocker | What to Check | How to Fix |
|---------|---------------|------------|
| **No valid recommendation** | No `*.rightsizing.kubex.ai/desired-resource-requests` annotation on pod for the target container. | Verify Kubex platform has analyzed this workload and generated recommendations. Check recommendation age and policy configuration. |
| **Recommendation too old** (`maxAnalysisAgeDays` exceeded) | Check the age of the recommendation in the Kubex platform. | Re-analyze the workload or increase `maxAnalysisAgeDays` in your policy. |
| **Recommendation not syncing to pod** | Controller may not be copying recommendations from workload owners to pods. | Check ProactivePolicy or StaticPolicy configuration. Verify controller logs for sync errors. |

### Resource Conflict Blockers (Critical - Requires Immediate Action)

| Blocker | What to Check | How to Fix |
|---------|---------------|------------|
| **HPA detected** (`hpa-detected` in `failedChecks`) | HorizontalPodAutoscaler exists for this workload. | Remove the HPA or use VPA instead. HPA and rightsizing cannot coexist. See [FAQ](./FAQ.md). |
| **VPA overlap** | VerticalPodAutoscaler exists for this workload. | Remove the VPA or disable rightsizing for this workload. |
| **ResourceQuota conflict** | Namespace ResourceQuota limits would be exceeded by the new resource values. | Increase quota limits or reduce resource recommendations. |
| **LimitRange conflict** | Namespace LimitRange constraints conflict with recommended values. | Adjust LimitRange constraints or modify policy bounds. |

### Workload Availability Blockers (Temporary - Usually Auto-Resolves)

| Blocker | What to Check | How to Fix |
|---------|---------------|------------|
| **Pod not ready** | Pod readiness or workload availability protection triggered. | Wait for pod to become ready. Check if enough replicas are available. See [Safety Controls](./Safety-Controls.md). |
| **Not enough available replicas** | Workload availability check requires minimum ready replicas before automation. | Scale up the workload or adjust `minAvailableReplicas` in your AutomationStrategy. |
| **Node headroom insufficient** | Not enough allocatable resources on nodes to support the resize. | Add more nodes or reduce resource recommendations. |

### Webhook and System Blockers (Configuration Issues)

| Blocker | What to Check | How to Fix |
|---------|---------------|------------|
| **Webhook health probe failure** | Webhook health condition shows unhealthy in GlobalConfiguration status. | Check webhook probe configuration. Verify probe pod can be created. See below for image policy issues. |
| **Webhook probe denied by image policy** | Admission webhook or image policy rejects the probe pod. | Set `globalConfiguration.webhookProbe.image` to an allowed mirrored image. On EKS, verify probe pod has `eks.amazonaws.com/skip-pod-identity-webhook: "true"` label. |
| **Webhook mutation missing** | New pods don't have mutation applied but admission succeeds. | Check webhook runtime or API communication failures. See [Tuning Guide](./Tuning-Guide.md#admission-webhook-fail-open-semantics). |
| **Protected namespace** | Namespace matches `protectedNamespacePatterns` in GlobalConfiguration. | Remove the namespace from protected patterns or choose a different namespace. |
| **Automation globally disabled** | `spec.automationEnabled=false` in GlobalConfiguration. | Set `spec.automationEnabled=true` in GlobalConfiguration. |

### Workload-Specific Blockers (Rare)

| Blocker | What to Check | How to Fix |
|---------|---------------|------------|
| **StrimziPodSet pods not matched** | StrimziPodSet selector doesn't match expected pods. | Verify the StrimziPodSet has a non-empty `spec.selector` and that pods in the namespace match it. |
| **Unsupported workload type** | Workload owner type is not supported. | Check [supported workload types](./Getting-Started.md). Standalone pods (no owner) require StaticPolicy. |

## 6. Verify Webhook Registration

The mutating admission webhook intercepts pod creation and applies resource recommendations. If the webhook isn't registered properly, new pods won't get recommendations applied.

### Check Webhook Configuration

```bash
# List all mutating webhooks
kubectl get mutatingwebhookconfigurations.admissionregistration.k8s.io
```

**Expected output:** You should see a webhook configuration with a name like `kubex-automation-engine-mutating-webhook-configuration`.

### Verify Webhook Details

```bash
# Inspect webhook configuration details
kubectl describe mutatingwebhookconfigurations.admissionregistration.k8s.io <webhook-name>
```

**What to check**:
- **Rules** - Should match pods in your target namespaces
- **Failure Policy** - Usually `Ignore` (fail-open) to prevent blocking pod creation if webhook is down
- **Service** - Should point to the controller service
- **CA Bundle** - Should be present (base64-encoded certificate)

### Common Issues

**Webhook not found**
```
No resources found
```
**Fix**: The webhook may not have been created during installation. Check Helm values and reinstall if necessary.

**Webhook not being called**
- **Check namespace labels**: Some webhooks use `namespaceSelector` to filter which namespaces they apply to
- **Check object selector**: Webhook may filter based on pod labels or annotations
- **Check failure policy**: If set to `Fail`, webhook failures will block pod creation (rare)

**Webhook failing but pods still created**
- This is **expected behavior** with `failurePolicy: Ignore` (fail-open)
- Pods are created, but recommendations aren't applied
- Check webhook health in GlobalConfiguration (step 2)
- Check controller logs for webhook errors

### Additional Resources

For advanced webhook tuning in slow or degraded environments, see [Tuning Guide](./Tuning-Guide.md).

---

## Quick Diagnostic Commands

### View Automation State and Blockers

```bash
# View all automation blockers for a specific pod (requires jq)
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.metadata.annotations.rightsizing\.kubex\.ai/automation-constraints}' | jq .

# View only BLOCKER type reasons (requires jq)
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.metadata.annotations.rightsizing\.kubex\.ai/automation-constraints}' | jq '.reasons[] | select(.reasonType=="BLOCKER")'

# View current recommendations on a pod (requires jq)
kubectl get pod <pod-name> -n <namespace> -o json | jq '.metadata.annotations | with_entries(select(.key | contains("desired-resource")))'
```

### Check Control Annotations

```bash
# Find all paused pods in a namespace
kubectl get pods -n <namespace> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.rightsizing\.kubex\.ai/pause-until}{"\n"}{end}' | grep -v '<none>'

# Find all pods with skip-containers set
kubectl get pods -n <namespace> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.rightsizing\.kubex\.ai/skip-containers}{"\n"}{end}' | grep -v '<none>'

# Check if namespace has pause annotation
kubectl get namespace <namespace> -o jsonpath='{.metadata.annotations.rightsizing\.kubex\.ai/pause-until}'
```

### Check Rollback State (Pod Owners)

```bash
# View rollback state on a Deployment (requires jq)
kubectl get deployment <deployment-name> -n <namespace> -o jsonpath='{.metadata.annotations.rightsizing\.kubex\.ai/rollback-state}' | jq .

# View rollback state on a StatefulSet (requires jq)
kubectl get statefulset <statefulset-name> -n <namespace> -o jsonpath='{.metadata.annotations.rightsizing\.kubex\.ai/rollback-state}' | jq .
```

### Collect Support Information

If automation still isn't working after following all troubleshooting steps, collect this information:

```bash
# Controller logs (last 200 lines)
kubectl logs -n kubex -l control-plane=controller-manager -c manager --tail=200 > controller-logs.txt

# GlobalConfiguration
kubectl get globalconfiguration global-config -o yaml > global-config.yaml

# Affected pod details
kubectl get pod <pod-name> -n <namespace> -o yaml > pod-details.yaml

# Policy and strategy
kubectl describe proactivepolicy <policy-name> -n <namespace> > policy-details.txt
kubectl describe automationstrategy <strategy-name> -n <namespace> > strategy-details.txt

# Recent events
kubectl get events -n <namespace> --sort-by='.lastTimestamp' --field-selector involvedObject.name=<pod-name> > pod-events.txt
```

For performance tuning and optimization, see [Tuning Guide](./Tuning-Guide.md).

---

## Enable Debug Logging (Rarely Needed)

> **⚠️ Debug logging is rarely needed.** The controller provides extensive troubleshooting information via annotations (`automation-constraints`, `rollback-state`), events (`PrecheckFailed`, policy evaluation outcomes), and info-level summary logs. Only enable debug logging when:
> - Investigating controller internal behavior not visible in annotations or events
> - Troubleshooting controller crashes or performance issues
> - Requested by Kubex support for deep diagnostics
>
> Always start with annotations, summary logs, and events before enabling debug logging.

Most of the time you only want debug logs briefly. The quickest way is to update the live Deployment args (this triggers a rollout and will be overwritten by the next `helm upgrade`).

**Enable debug (temporary):**

```bash
# Patches the controller deployment to enable debug logging
kubectl -n kubex patch deploy/$(kubectl -n kubex get deploy -l app.kubernetes.io/name=kubex-automation-engine -o jsonpath='{.items[0].metadata.name}') \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/args/3","value":"--zap-log-level=debug"}]'
```

**Revert back to info:**

```bash
# Restores info-level logging
kubectl -n kubex patch deploy/$(kubectl -n kubex get deploy -l app.kubernetes.io/name=kubex-automation-engine -o jsonpath='{.items[0].metadata.name}') \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/args/3","value":"--zap-log-level=info"}]'
```

If you want the setting to persist across upgrades, use Helm instead:

**Enable debug (persistent):**

```bash
# Sets debug logging via Helm - persists across upgrades
helm upgrade kubex-automation kubex/kubex-automation-engine -n kubex \
  --reuse-values \
  --set 'controllerManager.extraArgs[0]=--zap-log-level=debug'
```

**Revert with Helm:**

```bash
# Restores info-level logging via Helm
helm upgrade kubex-automation kubex/kubex-automation-engine -n kubex \
  --reuse-values \
  --set 'controllerManager.extraArgs[0]=--zap-log-level=info'
```
