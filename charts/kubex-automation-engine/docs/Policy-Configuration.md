# Policy Configuration Guide

This guide explains the strategy-and-policy model and how the chart's Helm values map to CRs.

Use this page for the configuration model. Use [Getting Started](./Getting-Started.md) for installation, first-time setup, and validation steps.

For CR-specific field references and examples, see:

- [Automation Strategies](./Automation-Strategies.md)
- [Cluster Automation Strategies](./Cluster-Automation-Strategies.md)
- [Proactive Policies](./Proactive-Policies.md)
- [Cluster Proactive Policies](./Cluster-Proactive-Policies.md)
- [Static Policies](./Static-Policies.md)

## Configuration Model

The controller separates automation into two concerns:

- **Strategy** defines how resizing is allowed to happen.
- **Policy** defines where that behavior applies and whether targets come from recommendations or fixed resource values.

At the CRD level:

- `AutomationStrategy` and `ClusterAutomationStrategy` define resize behavior.
- `ProactivePolicy` and `ClusterProactivePolicy` apply recommendation-driven automation coming from Kubex.
- `StaticPolicy` and `ClusterStaticPolicy` apply fixed request and limit values.

Use the namespaced pages for namespace-owned CRs and the cluster-scoped pages for platform-owned, cross-namespace CRs.

Reference rules:

- `ProactivePolicy` references a namespaced `AutomationStrategy` in the same namespace.
- `StaticPolicy` references a namespaced `AutomationStrategy` in the same namespace and also includes explicit `resources`.
- `ClusterProactivePolicy` references a `ClusterAutomationStrategy`.
- `ClusterStaticPolicy` references a `ClusterAutomationStrategy` and also includes explicit `resources`.

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

Those resources remain fully supported by the controller and can be managed outside Helm when you need them.

## Values To Resource Mapping

| Helm value | Generated resource | Notes |
| --- | --- | --- |
| `policy.policies.<name>` | `ClusterAutomationStrategy` | One cluster strategy per policy entry. |
| `scope[].name` | `ClusterProactivePolicy.metadata.name` | One cluster proactive policy per scope entry. |
| `scope[].policy` or `policy.defaultPolicy` | `ClusterProactivePolicy.spec.automationStrategyRef.name` | References the generated or externally managed `ClusterAutomationStrategy` with that name. |
| `scope[].namespaces` | `ClusterProactivePolicy.spec.scope.namespaceSelector` | Namespace include or exclude rules. |
| `scope[].podLabels` | `ClusterProactivePolicy.spec.scope.labelSelector` | Converted into `matchLabels` or `matchExpressions`. |
| `scope[].weight` | `ClusterProactivePolicy.spec.weight` | Higher weight wins within the same policy type. |
| `policy.policies.<name>.allowedPodOwners` | `ClusterProactivePolicy.spec.scope.workloadTypes` | Supported values: `Deployment`, `StatefulSet`, `DaemonSet`, `CronJob`, `Rollout`, `Job`, `AnalysisRun`. |
| `policy.policies.<name>.safetyChecks.maxAnalysisAgeDays` | `ClusterProactivePolicy.spec.safetyChecks.maxAnalysisAgeDays` | Per-policy value wins over top-level `policy.safetyChecks.maxAnalysisAgeDays`. |
| `policy.safetyChecks.maxAnalysisAgeDays` | `ClusterProactivePolicy.spec.safetyChecks.maxAnalysisAgeDays` | Backward-compatible fallback when not set per policy. |

Important:

- `maxAnalysisAgeDays` is written to generated `ClusterProactivePolicy` resources, not to generated strategies.
- `ReplicaSet` is not supported in `allowedPodOwners`; use `Deployment` to cover Deployment-managed pods.
- Helm can reference a `ClusterAutomationStrategy` that was created outside Helm if the names match.

## Strategy Settings Exposed By Helm

For each `policy.policies.<name>` entry, Helm can populate these `ClusterAutomationStrategy` settings:

- `enablement.cpu.requests.*`
- `enablement.cpu.limits.*`
- `enablement.memory.requests.*`
- `enablement.memory.limits.*`
- `inPlaceResize.*`
- `podEviction.*`

For the full strategy CRD surface, manage `ClusterAutomationStrategy` directly with manifests.

See [Cluster Automation Strategies](./Cluster-Automation-Strategies.md) and [Cluster Proactive Policies](./Cluster-Proactive-Policies.md) for the cluster-scoped CRD field references and examples.

## When To Manage CRs Outside Helm

Manage CRs outside Helm when you need:

- namespaced strategies or policies
- fixed-resource policies
- cluster proactive policies that are not tied to chart values
- cluster automation strategies that are shared, versioned, or promoted independently of Helm releases
- advanced strategy safety checks beyond the Helm-managed subset

This external-CR pattern applies equally to cluster-scoped and namespaced resources. `ClusterAutomationStrategy` and `ClusterProactivePolicy` are not Helm-only resource types.

## Scope Design Guidance

- Prefer mutually exclusive scopes so winner selection stays predictable.
- Use `weight` deliberately when multiple cluster proactive policies may match.
- Start with narrow namespace and label selectors before widening scope.
- Exclude system and platform namespaces from broad proactive automation.
- Use static policies when exact requests and limits matter more than recommendation-driven tuning.

## Precedence And Overlap

When more than one policy matches, the controller resolves a winner by policy-type precedence and then by weight. If you expect overlap, set weights explicitly and verify the selected policy in events and `rightsizing summary` logs.
