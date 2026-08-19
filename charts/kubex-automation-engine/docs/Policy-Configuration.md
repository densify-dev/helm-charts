# Policy Configuration Guide

This guide explains the strategy-and-policy model and how the chart's Helm values map to CRs.

Use this page for the configuration model. Use [Getting Started](./Getting-Started.md) for installation, first-time setup, and validation steps.

For CR-specific field references and examples, see:

- [Automation Strategies](./Automation-Strategies.md)
- [Cluster Automation Strategies](./Cluster-Automation-Strategies.md)
- [Proactive Policies](./Proactive-Policies.md)
- [Cluster Proactive Policies](./Cluster-Proactive-Policies.md)
- [Static Policies](./Static-Policies.md)
- [Cluster Compaction Policies](./Cluster-Compaction-Policies.md)
- [Rollback Policies](./Rollback-Policies.md)

## Configuration Model

The controller separates automation into two concerns:

- **Strategy** defines how resizing is allowed to happen.
- **Policy** defines where that behavior applies and whether targets come from recommendations or fixed resource values.

At the CRD level:

- `AutomationStrategy` and `ClusterAutomationStrategy` define resize behavior.
- `ProactivePolicy` and `ClusterProactivePolicy` apply recommendation-driven automation coming from Kubex.
- `StaticPolicy` and `ClusterStaticPolicy` apply fixed request and limit values.
- `ClusterCompactionPolicy` applies active bin-packing and descheduler/scheduler compaction behavior across namespaces.
- `PodAffinityPolicy` applies preferred hostname-based node affinity to replacement pods and can force eviction-based rescheduling when its affinity rule must be enforced during evaluation.
- `ContainerArgsPolicy` applies named command-line argument operations to selected workload containers during pod admission and can optionally converge existing pods through eviction.
- `RollbackPolicy` and `ClusterRollbackPolicy` enable and configure rollback monitoring and backoff settings. **These policies are required for rollback functionality** - without a matching policy, workloads will not be monitored for health failures and rollback will not occur.

Use the namespaced pages for namespace-owned CRs and the cluster-scoped pages for platform-owned, cross-namespace CRs.

Reference rules:

- `ProactivePolicy` references a namespaced `AutomationStrategy` in the same namespace.
- `StaticPolicy` references a namespaced `AutomationStrategy` in the same namespace and also includes explicit `resources`.
- `ClusterProactivePolicy` references a `ClusterAutomationStrategy`.
- `ClusterStaticPolicy` references a `ClusterAutomationStrategy` and also includes explicit `resources`.
- `ClusterCompactionPolicy` manages compaction implementation mode and scope for active bin-packing, including per-policy descheduler placement and node selectors.

All of these CR types can be created outside Helm with manifests, GitOps, or `kubectl`.

## Helm-Managed Mapping

The chart's `scope` and `policy.policies` values provide a convenience layer for creating a cluster-scoped recommendation-driven setup.

When `policy.policies` is populated, the chart renders one `ClusterAutomationStrategy` per policy entry.

When `scope` is populated, the chart renders one `ClusterProactivePolicy` per scope entry.

This Helm-managed flow creates only these CR types:

- `ClusterAutomationStrategy`
- `ClusterProactivePolicy`

It does **not** create:

- `AutomationStrategy`
- `ProactivePolicy`
- `StaticPolicy`
- `ClusterStaticPolicy`
- `RollbackPolicy`
- `ClusterRollbackPolicy`
- `ContainerArgsPolicy`

Those resources remain fully supported by the controller and can be managed outside Helm when you need them.

Rollback policies are also fully supported by the controller and must be managed outside Helm when you need health monitoring and automatic rollback after failed resizes.

## Values To Resource Mapping

| Helm value | Generated resource | Notes |
| --- | --- | --- |
| `policy.policies.<name>` | `ClusterAutomationStrategy` | One cluster strategy per policy entry. |
| `scope[].name` | `ClusterProactivePolicy.metadata.name` | One cluster proactive policy per scope entry. |
| `scope[].policy` or `policy.defaultPolicy` | `ClusterProactivePolicy.spec.automationStrategyRef.name` | References the generated or externally managed `ClusterAutomationStrategy` with that name. |
| `scope[].namespaces` | `ClusterProactivePolicy.spec.scope.namespaceSelector` | Namespace include or exclude rules. |
| `scope[].podLabels` | `ClusterProactivePolicy.spec.scope.labelSelector` | Converted into `matchLabels` or `matchExpressions`. |
| `scope[].weight` | `ClusterProactivePolicy.spec.weight` | Higher weight wins within the same policy type. |
| `policy.policies.<name>.allowedPodOwners` | `ClusterProactivePolicy.spec.scope.workloadTypes` | Supported values: `Deployment`, `StatefulSet`, `DaemonSet`, `CronJob`, `Rollout`, `Job`, `AnalysisRun`, `StrimziPodSet` (opt-in), `Model`. |
| `policy.policies.<name>.safetyChecks.maxAnalysisAgeDays` | `ClusterProactivePolicy.spec.safetyChecks.maxAnalysisAgeDays` | Per-policy value wins over top-level `policy.safetyChecks.maxAnalysisAgeDays`. |
| `policy.safetyChecks.maxAnalysisAgeDays` | `ClusterProactivePolicy.spec.safetyChecks.maxAnalysisAgeDays` | Backward-compatible fallback when not set per policy. |

### Namespace wildcards in `scope[].namespaces.values`

`scope[].namespaces.values` supports shell-style `*` wildcards when matching namespace names (for example: `prod-*`).

```yaml
scope:
  - name: platform
    namespaces:
      operator: In
      values: ["prod-*", "staging"]
```

Important:

- **Wildcard patterns must be enclosed in double quotes** (e.g., `"prod-*"`, not `prod-*`) to ensure proper YAML parsing.
- `maxAnalysisAgeDays` is written to generated `ClusterProactivePolicy` resources, not to generated strategies.
- `ReplicaSet` is not supported in `allowedPodOwners`; use `Deployment` to cover Deployment-managed pods.
- `StrimziPodSet` support is opt-in in `allowedPodOwners`.
- `Model` is included in default workload types when policy `workloadTypes` is omitted. Keep `allowedPodOwners: [Model]` when you want Helm-generated scope restricted to KubeAI `Model` objects only.
- Helm can reference a `ClusterAutomationStrategy` that was created outside Helm if the names match.

Example:

```yaml
scope:
  - name: kubeai-models
    policy: balanced
    namespaces:
      operator: In
      values: ["*"]
    allowedPodOwners:
      - Model
```

## Strategy Settings Exposed By Helm

For each `policy.policies.<name>` entry, Helm can populate these `ClusterAutomationStrategy` settings:

- `enablement.cpu.requests.*`
- `enablement.cpu.limits.*`
- `enablement.memory.requests.*`
- `enablement.memory.limits.*`
- `inPlaceResize.*`
- `podEviction.*`
- `safetyChecks.*` except `maxAnalysisAgeDays`, which is written to `ClusterProactivePolicy`

Helm does not currently expose strategy scheduling windows such as `spec.scheduling.inclusionWindows` and `spec.scheduling.exclusionWindows`.

For the full strategy CRD surface, including scheduling, manage `ClusterAutomationStrategy` directly with manifests.

See [Cluster Automation Strategies](./Cluster-Automation-Strategies.md) and [Cluster Proactive Policies](./Cluster-Proactive-Policies.md) for the cluster-scoped CRD field references and examples.

## When To Manage CRs Outside Helm

Manage CRs outside Helm when you need:

- namespaced strategies or policies
- fixed-resource policies
- cluster proactive policies that are not tied to chart values
- cluster automation strategies that are shared, versioned, or promoted independently of Helm releases
- advanced strategy safety checks beyond the Helm-managed subset
- scheduling windows that restrict when automation can run

This external-CR pattern applies equally to cluster-scoped and namespaced resources. `ClusterAutomationStrategy` and `ClusterProactivePolicy` are not Helm-only resource types.

## PodAffinityPolicy Behavior

`PodAffinityPolicy` is a cluster-scoped CR that is supported by the controller but managed outside Helm today.

Use it when you want replacement pods to prefer a specific set of node hostnames via `spec.affinity.nodes`.

Behavior summary:

- Admission always injects preferred `kubernetes.io/hostname In [...]` node affinity into newly created replacement pods.
- During policy evaluation, eviction is enabled whenever the managed preferred hostname affinity on the pod would need to change.
- `spec.affinity.checkCurrentNodeSatisfiesAffinity` defaults to `false`.
- When `spec.affinity.checkCurrentNodeSatisfiesAffinity` is `true`, policy evaluation also checks the current node hostname. If the running pod is on a node whose `kubernetes.io/hostname` label is not in `spec.affinity.nodes`, eviction is enabled even when the pod already has the intended managed affinity.

Warning:

- Enabling `spec.affinity.checkCurrentNodeSatisfiesAffinity` can cause eviction loops if the workload cannot actually land on one of the intended nodes. This can happen when scheduler constraints, taints, missing tolerations, topology rules, resource pressure, or other placement rules keep replacement pods off the target nodes.
- Prefer enabling this setting only when you know the target nodes are schedulable for the workload and the preferred hostname list is stable.

## ContainerArgsPolicy Behavior

`ContainerArgsPolicy` is a cluster-scoped CR managed outside Helm or through proposal sync. It targets workload kinds, namespaces, and labels through `spec.scope`, then writes one runtime-hook recommendation to matching workloads.

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ContainerArgsPolicy
metadata:
  name: inference-server-args
spec:
  scope:
    workloadTypes: [Deployment, StatefulSet]
    namespaceSelector:
      operator: In
      values: ["inference-*"]
    labelSelector:
      matchLabels:
        app: model-server
  containers:
    "*":
      args:
        - name: --disable-log-stats
          operation: Remove
    server:
      args:
        - name: --gpu-memory-utilization
          value: "0.8"
        - name: --enable-prefix-caching
        - name: -v
          value: "3"
  replaceExistingPods: false
  weight: 100
```

Argument rules:

- `operation` defaults to `AddOrUpdate`; `Remove` deletes every matching equals or split-form occurrence.
- Omitted `value` emits a valueless flag. `value: ""` emits an explicit empty value.
- Existing `--option=value`, `--option value`, and `-o value` forms are replaced in place when possible. Missing valued options append in split form.
- Duplicate existing options are collapsed. Duplicate policy entries remain in declared order.
- Wildcard rules apply to all regular containers and restartable sidecars. A named container rule overrides wildcard entries with the same option name; missing named containers are skipped.
- Option names must be literal names beginning with `-` or `--`, with no whitespace or `=`. Combined short flags, attached short values, shell strings, positional edits, and `command` edits are unsupported.
- Malformed existing argument streams use best-effort replacement; unrelated arguments keep their order.
- This API does not parse shell strings, edit `command` or positional arguments, detect executables/vLLM, merge policies, patch workload templates, or evict pods directly.

Only one matching `ContainerArgsPolicy` is selected using PolicyEvaluation type priority, policy weight, and existing deterministic tie-breaking. Policies do not merge across resources.

`replaceExistingPods` defaults to `false`, so admission mutation affects new pods only. Set it to `true` to let PolicyEvaluation request eviction when effective managed arguments drift; the controller does not patch workload templates or evict pods directly. This can disrupt workloads and should be enabled only with deliberate disruption controls.

When a selected `ContainerArgsPolicy` hook has no resolved `AutomationStrategy`, PolicyEvaluation implicitly enables eviction and retries PodDisruptionBudget-blocked evictions. It requeues those retries every 30 seconds. A resolved strategy's `podEviction` and `safetyChecks.resizeRetryInterval` settings remain authoritative.

KAI vLLM tuning runs after runtime hooks and changes `--gpu-memory-utilization`. Conflicting KAI and ContainerArgsPolicy values may cause repeated replacement requests.

Proposal sync supports `ContainerArgsPolicy` as a cluster-scoped proposal kind. Proposal metadata must omit `namespace`. Helm does not create policy instances or expose a values mapping for this API.

## Scope Design Guidance

- Prefer mutually exclusive scopes so winner selection stays predictable.
- Use `weight` deliberately when multiple cluster proactive policies may match.
- Start with narrow namespace and label selectors before widening scope.
- Exclude system and platform namespaces from broad proactive automation.
- Use static policies when exact requests and limits matter more than recommendation-driven tuning.

## Precedence And Overlap

When more than one policy matches, the controller resolves a winner using this order:

1. **Policy-type precedence** (static vs. proactive)
2. **Weight** (higher wins)
3. **Creation time** (newer wins if weights are equal)

### Policy Type Precedence

By default, static policies (fixed resources) take precedence over proactive policies (recommendations). This is controlled by the `PolicyEvaluation` singleton resource. `ContainerArgsPolicy` has default priority 100 so overlapping argument-hook policies are selected predictably; its `weight` resolves overlap between instances.

**Default precedence:**
- `ContainerArgsPolicy`: priority 100
- `StaticPolicy` and `ClusterStaticPolicy`: priority 90
- `ProactivePolicy` and `ClusterProactivePolicy`: priority 70

To favor recommendation-driven automation instead, create or edit the `policy-evaluation` resource:

- Start from the default `PolicyEvaluation` example in [Policy Evaluation](./Policy-Evaluation.md#default-behavior).
- Change the priorities so proactive policy types win:
  - Set `ProactivePolicy` and `ClusterProactivePolicy` to `priority: 90`
  - Set `StaticPolicy` and `ClusterStaticPolicy` to `priority: 70`

For the complete reference, see [Policy Evaluation](./Policy-Evaluation.md).

To verify which policy was selected, check controller events or `rightsizing summary` logs.
