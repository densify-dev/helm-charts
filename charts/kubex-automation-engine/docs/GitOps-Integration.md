# GitOps Integration

Kubex Automation Engine works alongside GitOps controllers such as Argo CD and Flux. GitOps manages workload manifests and Kubex configuration; Kubex evaluates recommendations and applies approved resource changes to running pods.

This guide covers the engine's rightsizing capabilities and the ownership boundaries around them.

Kubex does not require write-back access to the Git repository for runtime rightsizing. It changes eligible live Pods and leaves the Git-managed workload template unchanged. Teams can copy recommendations back into their manifests during a planned review when they want to make a new baseline permanent, but that is an optional operating process rather than a Kubex requirement.

## Ownership and reconciliation

Keep ownership clear between the two systems:

| Resource or behavior | Recommended owner |
| --- | --- |
| Workloads and pod templates | GitOps |
| `AutomationStrategy` and `ClusterAutomationStrategy` | GitOps or another external manifest workflow |
| `ProactivePolicy` and `ClusterProactivePolicy` | GitOps or another external manifest workflow |
| Kubex controller settings | GitOps or another external manifest workflow |
| Runtime pod-level resource changes | Kubex Automation Engine |

Kubex resizes individual pods during their admission or in-place. It does not modify the owner workload's pod template, so the GitOps controller continues to see the declared workload resources as the desired baseline. 

Kubex can resize in place or evict a pod for replacement, depending on `AutomationStrategy`. In the replacement flow, the owner creates a pod from its unchanged template and the admission webhook applies the eligible recommendation. The template remains Git-managed.

Runtime sizing is not a replacement for the workload template. If a Pod is recreated while Kubex is unavailable, or while its admission webhook cannot apply a recommendation, the replacement starts from the template's declared resources. The webhook is fail-open, so an admission failure results in a Pod being admitted without the Kubex mutation rather than blocking Pod creation; see [Admission Webhook Fail-Open Semantics](./Tuning-Guide.md#admission-webhook-fail-open-semantics). When the webhook is healthy and a recommendation is available, newly created Pods can be mutated again during admission.

Manage strategy and policy CRs independently, and ensure that each resource has one declarative owner.

Workload manifests are also organization-specific. They may be maintained in an application repository, an environment repository, or another source consumed by your GitOps tooling. Kubex does not require them to be stored in a particular directory or repository. Wherever they are managed, GitOps should remain the owner of the workload template, while Kubex owns eligible runtime pod-level resource changes.

### Argo CD and Flux ownership

For Argo CD, one application can manage Kubex controller resources and another can manage Kubex strategy and policy resources. For Flux, the same separation can be represented by separate reconciliation boundaries, with a `Kustomization` applying strategy and policy resources independently. Adapt the source reference, path, namespace, and application boundaries to your GitOps setup. Keep policy changes independently reviewable, and ensure that only one reconciliation path owns each strategy or policy resource.

## Agentic proposals and GitOps

Kubex agentic proposals can create `ClusterObjectPatch` resources. A human must review and approve each proposal before Kubex applies its patch. A `ClusterObjectPatch` changes the live cluster-scoped object named by its target reference, so the target may also be tracked and reconciled by a GitOps controller.

When the target is GitOps-managed, the `ClusterObjectPatch` controller does not identify GitOps reconciliation specially. Without `spec.drift`, it reports that the target has drifted but does not repair it. With `spec.drift` configured, it retries drift repairs using the configured interval and retry limit; after the limit is reached, it stops and marks the patch as failed until the spec changes or the patch is explicitly reapplied. See [Object Patches: Lifecycle and Status](./Object-Patches.md#lifecycle-and-status) for the `spec.drift` settings and retry behavior. To avoid repeated conflicts, configure the GitOps controller to ignore the fields managed by the patch, or update the corresponding Git-managed object in your repository so GitOps records the desired state.

Agentic proposals that create objects instead of modifying existing GitOps-managed objects do not conflict with GitOps reconciliation. You may still choose to define those objects in GitOps so the repository remains the source of truth—for example, manage a `ClusterCompactionPolicy` there.

## Runtime flow

After the GitOps applications have applied their resources, the runtime flow is:

1. GitOps applies the workload template and Kubex strategy/policy resources.
2. Kubex evaluates recommendations and resizes eligible pods, or evicts them when replacement is required.
3. GitOps continues reconciling the unchanged workload template.
4. When the template changes in Git, new pods use the new baseline and Kubex can apply recommendations during admission or later evaluation.

## Inspecting effective resources

GitOps generally will not report a Kubex pod resize as drift in the owner workload. Compare the live pod with its GitOps-managed owner template when needed:

```bash
kubectl get pod <pod-name> -n <namespace> \
  -o jsonpath='{.spec.containers[*].resources}'

kubectl get deployment <deployment-name> -n <namespace> \
  -o jsonpath='{.spec.template.spec.containers[*].resources}'
```

These values can legitimately differ while Kubex automation is active.

## Operational guidance

- Keep workload requests and limits in Git as the desired baseline. Copy recommendations back into the manifest only when you want to make a sizing change permanent.
- If you change a workload's resources in its manifest because you expect its future utilization to differ from its historical usage, add a `rightsizing.kubex.ai/pause-until` annotation with a future date to the workload's pod template. This gives Kubex time to relearn the workload's utilization pattern before it produces a new recommendation, so the engine does not immediately resize the pod based on the old historical usage.
- Manage strategy and policy CRs declaratively so scope, safety controls, and enablement changes are reviewed and repeatable.
- Give GitOps ownership of workload templates and Kubex configuration resources, not of generated or individually managed pods.
- Do not configure another controller to continuously write the same pod-level resource values that Kubex resizes. When HPA or VPA is present, configure the Kubex safety filters and ownership boundaries deliberately.

Fallback after an unhealthy resize is a separate concern from GitOps reconciliation. Without a matching rollback policy, Kubex does not automatically roll back or retry a failed resize. With a [`RollbackPolicy` or `ClusterRollbackPolicy`](./Rollback-Policies.md), `spec.rollbackTarget` can select either the manifest baseline or the last successfully monitored resources. This health-based rollback does not make the live Pod's resources part of the Git-managed workload template.

For the configuration model and CR examples, see [Policy Configuration](./Policy-Configuration.md), [Automation Strategies](./Automation-Strategies.md), and [Getting Started](./Getting-Started.md).
