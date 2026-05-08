# Policy Evaluation Reference

`PolicyEvaluation` controls which policy type wins when multiple policy types match the same workload.

This is a cluster-scoped singleton resource named `policy-evaluation`.

## Default Behavior

By default, static policies (fixed resources) take precedence over proactive policies (recommendations):

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: PolicyEvaluation
metadata:
  name: policy-evaluation
spec:
  precedence:
  - type: StaticPolicy
    priority: 90
  - type: ClusterStaticPolicy
    priority: 90
  - type: ProactivePolicy
    priority: 70
  - type: ClusterProactivePolicy
    priority: 70
```

Higher priority values win. Within the same priority, the policy with the highest weight wins. If weights are also equal, the most recently created policy wins.

### Priority Field

`priority`: An integer value. Higher values take precedence. There is no enforced maximum; any positive integer is valid. Use consistent relative values (e.g., 70–100) to keep configurations readable.

## Common Configurations

### Favor Recommendations Over Fixed Values

To make recommendation-driven automation take precedence, start from the **Default Behavior** manifest above and change the priorities:

- Set `ProactivePolicy` and `ClusterProactivePolicy` to `priority: 90`
- Set `StaticPolicy` and `ClusterStaticPolicy` to `priority: 70`

### Favor Namespace Policies Over Cluster Policies

To prefer namespace-scoped policies, start from the **Default Behavior** manifest above and change the priorities:

- Set `StaticPolicy` to `priority: 100`
- Set `ProactivePolicy` to `priority: 90`
- Set `ClusterStaticPolicy` to `priority: 80`
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

Note: `priority` is set in the `PolicyEvaluation` CR and applies to all policies of that type. `weight` is set on each individual policy resource (e.g., `spec.weight` on a `StaticPolicy` or `ProactivePolicy`). See [Policy Configuration Guide](./Policy-Configuration.md) for how to set `weight` on policy resources.

**Example 1 - Default precedence:**
- `StaticPolicy` with `spec.weight: 50` (type has `priority: 90` in `PolicyEvaluation`)
- `ProactivePolicy` with `spec.weight: 100` (type has `priority: 70` in `PolicyEvaluation`)

Winner: `StaticPolicy` (policy-type priority 90 > 70, individual policy weight doesn't matter)

**Example 2 - Same policy type, different weights:**
- `ProactivePolicy` named `policy-a` with `spec.weight: 50`
- `ProactivePolicy` named `policy-b` with `spec.weight: 100`

Winner: `policy-b` (same policy-type priority, higher policy weight 100 > 50)

**Example 3 - Equal priority (custom configuration):**

If you've configured equal priority for static and proactive policies in `PolicyEvaluation`:

```yaml
precedence:
- type: StaticPolicy
  priority: 80
- type: ProactivePolicy
  priority: 80
```

And both match the same workload:
- `StaticPolicy` with `spec.weight: 50`
- `ProactivePolicy` with `spec.weight: 100`

Winner: `ProactivePolicy` (equal policy-type priority, so individual policy weight breaks the tie: 100 > 50)

**Example 4 - Equal priority and equal weight (creation-time tiebreaker):**

If priorities and weights are both equal, selection falls back to creation time (based on `metadata.creationTimestamp`): the most recently created policy wins.

- `StaticPolicy` with `spec.weight: 80`, created at 10:00
- `ProactivePolicy` with `spec.weight: 80`, created at 11:00

Winner: `ProactivePolicy` (equal priority, equal weight — most recently created policy wins)

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
