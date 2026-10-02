# Policy Evaluation Reference

`PolicyEvaluation` controls which policy type wins when multiple policy types match the same workload.

This is a cluster-scoped singleton resource named `policy-evaluation`.

## Default Behavior

By default, rollback policies take precedence over all other policy types.

The manifest below is the **complete chart-generated reference** for default policy precedence, not a usage example. `StaticPolicy` and `ClusterStaticPolicy` remain because they are actual chart defaults. Removing them would misrepresent the chart.

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: PolicyEvaluation
metadata:
  name: policy-evaluation
spec:
  precedence:
  - type: ContainerArgsPolicy
    priority: 100
  - type: PodAffinityPolicy
    priority: 100
  - type: RollbackPolicy
    priority: 130
  - type: ClusterRollbackPolicy
    priority: 130
  - type: GpuReactivePolicy
    priority: 120
  - type: ClusterGpuReactivePolicy
    priority: 110
  - type: StaticPolicy
    priority: 90
  - type: ClusterStaticPolicy
    priority: 90
  - type: ProactivePolicy
    priority: 70
  - type: ClusterProactivePolicy
    priority: 70
```

Higher priority values win. Within the same priority, the policy with the highest weight wins. For a resource, an exact container target wins over the wildcard target `"*"`. If those values are equal, the older policy wins only when both recommendations come from the same policy kind. The annotation key breaks all remaining ties, with the lexically smaller key winning. `ContainerArgsPolicy` uses this same selection order; its default priority is 100 and only one matching argument policy is selected.

Creation timestamps are added only to per-policy resource recommendations when multi-policy container rightsizing is enabled. Fixed-key resource recommendations and pod runtime hook recommendations keep their existing payload format.

### Priority Field

`priority`: An integer value. Higher values take precedence. There is no enforced maximum; any positive integer is valid. Use consistent relative values (e.g., 70–100) to keep configurations readable.

## Common Configurations

### Favor Rollback Policies Over Proactive Policies

To prefer rollback recommendations over proactive recommendations, start from the **Default Behavior** reference above and set the priorities:

- Set `RollbackPolicy` and `ClusterRollbackPolicy` to `priority: 130`
- Set `ProactivePolicy` and `ClusterProactivePolicy` to `priority: 70`

### Favor Namespace Policies Over Cluster Policies

To prefer namespace-scoped proactive policies over cluster-scoped proactive policies, start from the **Default Behavior** reference above and change the priorities:

- Set `ProactivePolicy` to `priority: 90`
- Set `ClusterProactivePolicy` to `priority: 70`

## Helm Configuration

The chart creates a default `PolicyEvaluation` when `policyEvaluation.enabled=true` (default: true).

To manage this resource manually:

> **Warning:** Before setting `policyEvaluation.enabled: false`, back up the existing resource:
> ```bash
> kubectl get policyevaluation policy-evaluation -o yaml > policy-evaluation-backup.yaml
> ```
> On the next `helm upgrade`, Helm will remove its managed copy. Apply your custom resource immediately afterward to avoid a gap in policy evaluation behavior.

```yaml
# values.yaml
policyEvaluation:
  enabled: false
```

Then create your own:

```bash
kubectl apply -f custom-policy-evaluation.yaml
```

## Selection Examples

Note: `priority` is set in the `PolicyEvaluation` CR and applies to all policies of that type. `weight` is set on each individual policy resource, such as `spec.weight` on a `ProactivePolicy`. See [Policy Configuration Guide](./Policy-Configuration.md) for how to set `weight` on policy resources.

**Example 1 - Default precedence:**
- `RollbackPolicy` with `spec.weight: 50` (type has `priority: 130` in `PolicyEvaluation`)
- `GpuReactivePolicy` with `spec.weight: 10` (type has `priority: 120` in `PolicyEvaluation`)
- `ClusterProactivePolicy` with `spec.weight: 50` (type has `priority: 70` in `PolicyEvaluation`)
- `ProactivePolicy` with `spec.weight: 100` (type has `priority: 70` in `PolicyEvaluation`)

Winner: `RollbackPolicy` because its policy-type priority of 130 exceeds 120 and 70, regardless of individual policy weight.

**Example 2 - Same policy type, different weights:**
- `ProactivePolicy` named `policy-a` with `spec.weight: 50`
- `ProactivePolicy` named `policy-b` with `spec.weight: 100`

Winner: `policy-b` (same policy-type priority, higher policy weight 100 > 50)

**Example 3 - Equal priority (custom configuration):**

If you've configured equal priority for cluster-scoped and namespaced proactive policies in `PolicyEvaluation`:

```yaml
precedence:
- type: ClusterProactivePolicy
  priority: 80
- type: ProactivePolicy
  priority: 80
```

And both match the same workload:
- `ClusterProactivePolicy` with `spec.weight: 50`
- `ProactivePolicy` with `spec.weight: 100`

Winner: `ProactivePolicy` (equal policy-type priority, so individual policy weight breaks the tie: 100 > 50)

**Example 4 - Same policy kind, equal priority and equal weight:**

If priorities, weights, and container targets are equal, selection uses creation time for recommendations from the same policy kind. The older policy wins. Legacy payloads without a timestamp rank as older than timestamped payloads.

With `multiPolicyContainerRightsizingEnabled: true`, both policies can publish recommendations for the same target:

- `ProactivePolicy` named `policy-a` with `spec.weight: 80`, created at 10:00
- `ProactivePolicy` named `policy-b` with `spec.weight: 80`, created at 11:00

Winner: `policy-a` because it has the older creation time. Recommendations from different policy kinds use the annotation key instead of comparing creation times.

## Multi-policy composition

When `GlobalConfiguration.spec.multiPolicyContainerRightsizingEnabled` is true, resource policies write policy-owned recommendation keys. `PolicyEvaluation` selects each container, request or limit, and resource independently, so same-kind policies can contribute separate targets. Ranking is policy-type priority, policy weight, exact container target over `"*"`, older creation time for equal-ranked policies of the same kind, then the lexically smaller annotation key. This can combine CPU, memory, and GPU values from different policies in one plan.

With the default setting (`false`), resource policies of the same kind share fixed annotation keys, so only one contributes to a workload. See [Multi-Policy Container Rightsizing](./Multi-Policy-Container-Rightsizing.md) for a two-container example and key-transition details.

The controller executes the selected actions only when they share an allowed method. One scheduling-window rejection blocks the full controller plan until the earliest next allowed time. Admission uses the same selected resources and safety checks but does not evaluate scheduling windows.

Combined requests and limits are validated without clamping. A request above a limit blocks the plan. Selected GPU actions also must agree on KAI mode, target container, allocation, and queue behavior.

## Verification

Check the active configuration:

```bash
kubectl get policyevaluation policy-evaluation -o yaml
```

View which policy was selected for a workload:

```bash
kubectl get events -A --field-selector involvedObject.name=<workload-name>
kubectl logs -n kubex -l control-plane=controller-manager | grep 'rightsizing summary'
```

## Related

- [Policy Configuration Guide](./Policy-Configuration.md) - Policy weight and scope configuration
- [Proactive Policies](./Proactive-Policies.md) - Recommendation-driven policies
- [Static Policies](./Static-Policies.md) - Fixed resource policies
