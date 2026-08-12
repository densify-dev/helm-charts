# Cluster Compaction Policies

## What is this feature?

Active bin-packing (compaction) consolidates your cluster's workloads onto fewer nodes so that underutilised nodes can be freed for scale-down or cost reduction. Without compaction, workloads that were spread across nodes during a traffic spike stay spread even after load drops — the cluster never self-consolidates.

`ClusterCompactionPolicy` is the Kubex API for declaring compaction intent. Each policy:

1. **Selects workloads** — by namespace, label selector, and workload type.
2. **Assigns a scheduler to new Pods** — the admission webhook directs newly created Pods for matching workloads to the Kubex compaction scheduler (or a nominated external scheduler), which uses a `MostAllocated` priority to pack them onto already-busy nodes.
   > **Note:** If your cluster's default scheduler can be configured to run in `MostAllocated` mode, that is preferable to deploying Kubex's own scheduler. Managed services such as GKE, AKS, and EKS allow you to change this setting — refer to your managed service documentation for details.
3. **Creates a descheduler** — the controller provisions a dedicated descheduler CronJob for the policy. Each run evicts pods that are on underutilised nodes, triggering re-scheduling onto denser nodes.
4. **Suppresses admission-convergence loops** — if runtime replacement repeatedly fails to apply the intended scheduler or labels, Kubex detects the loop fingerprint and temporarily excludes the workload from further compaction eviction.

## How to enable

### 1. Install the Helm chart with compaction support

```yaml
# values.yaml
compactionScheduler:
  enabled: true          # deploy the shared MostAllocated scheduler

compactionDescheduler:
  enabled: true          # deploy shared RBAC / service account for per-policy deschedulers
```

Helm installs only the ServiceAccount and RBAC for the compaction scheduler. The `kubex-compaction-scheduler` Deployment and its ConfigMap are fully owned by the controller: the Deployment is created on first reconcile and kept in sync thereafter (image tag auto-updated to match the cluster Kubernetes version; ConfigMap regenerated whenever policies change). No GitOps drift-ignore configuration is required.

### 2. Create a ClusterCompactionPolicy

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterCompactionPolicy
metadata:
  name: my-compaction-policy
spec:
  scope:
    namespaceSelector:
      operator: In
      values:
        - production
    workloadTypes:
      - Deployment
      - StatefulSet
  enabled: true
  setLabelsByEviction: true
  scheduler:
    useKubexScheduler: true
  descheduler:
    enabled: true
    maxNoOfPodsToEvictPerNode: 1
    maxNoOfPodsToEvictPerNamespace: 1
    maxNoOfPodsToEvictTotal: 1
    highNodeUtilization:
      numberOfNodes: 1
      thresholds:
        cpu: 65
        memory: 65
        pods: 65
```

This policy consolidates nodes whose request-based CPU, memory, and Pod utilization all fall below 65%. It uses the Kubex MostAllocated scheduler for new Pods in scope, evicts at most one Pod per node/namespace/run, and requires at least two underutilized nodes before acting. The descheduler runs every 30 minutes by default (`*/30 * * * *`).

The controller reconciles the policy, labels matched workloads, and creates the per-policy descheduler CronJob automatically. No further action is needed.

### 3. Verify

```bash
# Check the policy status
kubectl get clustercompactionpolicies -o wide

# Check the managed workloads have been labelled
kubectl get deployments -A -l scheduling.kubex.ai/compaction-policy=my-compaction-policy

# Check the per-policy descheduler CronJob
kubectl get cronjob -n kubex kubex-compaction-descheduler-my-compaction-policy
```

## Operational Model

- Helm installs the shared compaction scheduler support objects only.
- The controller generates the scheduler config and one descheduler CronJob/ConfigMap pair per active descheduler policy.
- `ClusterCompactionPolicy` chooses the effective policy per workload.
- Kubex-managed compaction workloads use scheduler name `kubex-compaction-scheduler`; external scheduler mode uses the configured external scheduler name instead.
- The scheduler image tag auto-defaults from the target cluster version unless explicitly overridden.

## Reference Rules

- `ClusterCompactionPolicy` is cluster-scoped.
- Multiple policies may match the same workload space.
- If multiple policies overlap, the controller resolves a single effective policy using `weight`, then scope specificity, then age, then name.
- Each effective policy gets a deterministic workload label: `scheduling.kubex.ai/compaction-policy=<policy-name>`.
- The shared suppression label is `scheduling.kubex.ai/compaction-suppressed=true`.
- The controller writes a versioned `scheduling.kubex.ai/compaction-intent` annotation to participating workload metadata. The Pod mutating admission webhook resolves the workload owner, reads that annotation, and sets compaction labels and `spec.schedulerName` on each new Pod. It does not modify the workload pod template or existing Pods.
- When `setLabelsByEviction` is enabled, the controller also writes a Pod runtime-hook recommendation. Existing Running Pods that missed the required admission state are replaced through the Kubernetes Eviction API one at a time per workload owner; their replacements receive compaction state during admission. PodDisruptionBudgets remain enforced.

## Workload type support

Scheduler assignment depends on whether admission can resolve an annotated supported owner. Descheduler support remains narrower because safe eviction and recreation semantics vary by workload controller.

| Workload type | Policy label | Scheduler assignment | Descheduler eviction | Notes |
|---|---|---|---|---|
| `Deployment` | ✅ | ✅ | ✅ | Existing Pods are not patched in place. With `setLabelsByEviction: true`, noncompliant Pods may be replaced through eviction. |
| `StatefulSet` | ✅ | ✅ | ✅ | Existing Pods are not patched in place. With `setLabelsByEviction: true`, noncompliant Pods may be replaced through eviction. |
| `DaemonSet` | ✅ | ✅ | — | SchedulerName is assigned at Pod admission; Pods are not evictable by `HighNodeUtilization` by default (`evictDaemonSetPods: false`). |
| `CronJob` | ✅ | ✅ | — | The webhook follows Pod → Job → CronJob and applies intent from the annotated CronJob. |
| `Rollout` (Argo) | ✅ | ✅ | — | The webhook resolves the Rollout owner; descheduler eviction depends on your Rollout strategy. |
| `Job` | ✅ | Limited | — | The initial Pod can race owner annotation; later retry Pods are mutated after intent is present. |
| `AnalysisRun` (Argo) | ✅ | Limited | — | The initial Pod can race owner annotation; later Pods are mutated after intent is present. |
| `StrimziPodSet` | ✅ | ✅ | — | Newly created or replacement Pods inherit intent through the owner reference. |
| `Model` (KubeAI) | ✅ | ✅ | — | Newly created or replacement model Pods inherit intent through the owner reference. |

**Known limitations**

- Scheduler assignment requires the Pod mutating admission webhook. Its failure policy is `Ignore`, so a Pod is admitted with its existing schedulerName when the webhook is unavailable.
- KAI GPU scheduling takes precedence when the same Pod receives both KAI resize actions and compaction intent. The webhook records this override in the controller log.
- Existing Pods are never rewritten to change scheduler assignment. When the runtime hook is enabled, admission-noncompliant Pods may be evicted and recreated; otherwise they retain their current scheduler and labels until naturally replaced.
- The compaction controller never modifies pod-template metadata or spec. Top-level workload metadata changes do not trigger a rollout.
- Admission uses the nearest annotated supported owner and falls back up the owner chain, such as from an unannotated Job to its annotated CronJob.
- `Job` and `AnalysisRun` scheduler assignment is best-effort because their controllers may create the initial Pod before compaction intent is reconciled onto the owner.

The runtime hook is controlled independently by `spec.setLabelsByEviction`. It honors `descheduler.nodeSelector`, `defaultEvictor.evictSystemCriticalPods`, `defaultEvictor.evictLocalStoragePods`, `defaultEvictor.ignorePvcPods`, and `defaultEvictor.evictDaemonSetPods`. It deliberately ignores `defaultEvictor.nodeFit`, `defaultEvictor.labelSelector`, the `maxNoOfPodsToEvict*` limits, `interval`, and `highNodeUtilization`; those settings govern descheduler balancing runs rather than admission convergence. Unscheduled, terminal, deleting, protected-namespace, and suppressed Pods are not replaced.

## Understanding utilization thresholds

`HighNodeUtilization` uses scheduled resource commitments, not live metrics:

- `cpu` is the sum of Pod CPU requests divided by node allocatable CPU.
- `memory` is the sum of Pod memory requests divided by node allocatable memory.
- `pods` is the number of scheduled Pods divided by the node's allocatable Pod capacity.

These values can differ substantially from `kubectl top nodes`, which reports recent measured consumption. For example, a node can consume 15% CPU while carrying requests equal to 70% of allocatable CPU; the descheduler uses 70%.

A node is an underutilized eviction source only when all three percentages are at or below their thresholds. With CPU `40`, memory `50`, and Pods `30`, a node at CPU `35`, memory `45`, and Pods `20` qualifies, while a node at CPU `41`, memory `20`, and Pods `10` does not.

Raising a threshold generally makes compaction more aggressive because nodes with more committed resources can qualify as sources. Lowering a threshold is more conservative. The relationship is not unlimited: if every selected node qualifies as underutilized, there is no denser destination and the strategy does nothing.

`numberOfNodes` is an activation gate. The strategy acts only when the count of underutilized nodes is greater than this value:

- `0` allows a run to act when at least one underutilized source exists.
- `1` requires at least two underutilized sources.
- Higher values are more conservative and are useful when avoiding disruption for a single temporarily sparse node.

The three eviction limits are cumulative safety caps. Every eviction must remain below the per-node, per-namespace, and total limits, so the smallest applicable cap controls the run. Raising a cap permits more disruption but does not create candidates when thresholds, PodDisruptionBudgets, placement constraints, or other safety filters reject them.

`nodeFit: true` conservatively checks whether a Pod appears able to fit on another ready node before eviction. This is an approximation, not a reservation or placement guarantee. Hard node affinity, anti-affinity, and `DoNotSchedule` topology-spread constraints can prevent consolidation or cause a replacement to return to its source node. Validate these constraints before enabling frequent descheduler runs.

`descheduler.nodeSelector` limits which nodes participate as sources and destinations in descheduler classification. It does not add node affinity to replacement Pods; use workload scheduling constraints when Pods must remain in a particular pool.

## Field Reference

| Field | Default | Description |
| --- | --- | --- |
| `spec.scope.labelSelector` | none | Kubernetes label selector for matching workloads. |
| `spec.scope.workloadTypes` | `[Deployment, StatefulSet, CronJob, Rollout, Job, AnalysisRun, DaemonSet, Model]` | Workload kinds this policy applies to. See the workload type support table above for per-type capabilities. |
| `spec.scope.namespaceSelector.operator` | none | Namespace selector operator: `In` or `NotIn`. |
| `spec.scope.namespaceSelector.values` | none | Namespace patterns to include or exclude (supports `*` wildcards, e.g. `prod-*`). |
| `spec.enabled` | `true` | Controls whether this policy participates in selection and enforcement. |
| `spec.scheduler.useKubexScheduler` | `true` | Controls whether matching workloads use the Kubex-managed compaction scheduler. |
| `spec.scheduler.externalSchedulerName` | none | External scheduler name used when `useKubexScheduler` is false. |
| `spec.setLabelsByEviction` | `true` | Controls whether existing Pods are replaced to converge with compaction scheduling intent. This does not control descheduler runs. |
| `spec.descheduler.enabled` | `true` | Controls whether matching workloads participate in descheduler-driven compaction. |
| `spec.descheduler.nodeSelector` | none | Limits source and destination classification to matching nodes. `In` and `NotIn` values support `*` wildcards. It does not constrain replacement Pod placement. |
| `spec.descheduler.maxNoOfPodsToEvictPerNode` | `1` | Maximum successful evictions from one source node per run. Higher values are more aggressive. |
| `spec.descheduler.maxNoOfPodsToEvictPerNamespace` | `1` | Maximum successful evictions from one namespace per run. Higher values are more aggressive. |
| `spec.descheduler.maxNoOfPodsToEvictTotal` | `1` | Maximum successful evictions across the whole run. Higher values are more aggressive. |
| `spec.descheduler.defaultEvictor.nodeFit` | `true` | Conservatively require the Pod to appear to fit on another ready node. This is not a placement guarantee. |
| `spec.descheduler.defaultEvictor.evictSystemCriticalPods` | `false` | Keep system-critical pods out of compaction by default. |
| `spec.descheduler.defaultEvictor.evictLocalStoragePods` | `false` | Avoid evicting local-storage pods by default. |
| `spec.descheduler.defaultEvictor.ignorePvcPods` | `true` | Ignore PVC-backed pods by default. |
| `spec.descheduler.defaultEvictor.evictDaemonSetPods` | `false` | Avoid evicting DaemonSet pods by default. |
| `spec.descheduler.defaultEvictor.labelSelector` | none | Adds Pod-label requirements to the implicit effective-policy selector. Pods must match both selectors. |
| `spec.descheduler.highNodeUtilization.numberOfNodes` | `0` | Strategy acts only when underutilized-node count is greater than this value. Higher values are more conservative. |
| `spec.descheduler.highNodeUtilization.thresholds.cpu` | `65` | Maximum requested CPU percentage for a source node. Higher values are generally more aggressive. |
| `spec.descheduler.highNodeUtilization.thresholds.memory` | `65` | Maximum requested memory percentage for a source node. Higher values are generally more aggressive. |
| `spec.descheduler.highNodeUtilization.thresholds.pods` | `65` | Maximum allocated Pod-capacity percentage for a source node. Higher values are generally more aggressive. |
| `spec.descheduler.interval` | `*/30 * * * *` | Five-field CronJob schedule for each one-shot run (e.g. `*/30 * * * *`, `0 */2 * * *`). Duration values such as `1m` and `30s` are invalid. |
| `spec.descheduler.loopDetectionWindow` | `15m` | Rolling window for counting repeated same-fingerprint admission-convergence replacements. |
| `spec.descheduler.loopDetectionThreshold` | `3` | Number of changed Pod observations within the window before suppression triggers. |
| `spec.descheduler.suppressionDuration` | `=loopDetectionWindow` | How long the suppressed label stays on the workload. |
| `spec.weight` | `0` | Higher weight wins when multiple compaction policies match. |

## Customer configuration examples

### Target selected production workloads conservatively

This policy targets only opted-in web workloads. Existing Pods are not replaced solely to add compaction admission state, and a run requires at least two underutilized nodes before evicting one Pod.

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterCompactionPolicy
metadata:
  name: production-web-conservative
spec:
  scope:
    namespaceSelector:
      operator: In
      values: [production]
    labelSelector:
      matchLabels:
        app.kubernetes.io/tier: web
        compaction.kubex.ai/enabled: "true"
    workloadTypes: [Deployment, StatefulSet]
  setLabelsByEviction: false
  scheduler:
    useKubexScheduler: true
  descheduler:
    enabled: true
    interval: "0 * * * *"
    maxNoOfPodsToEvictPerNode: 1
    maxNoOfPodsToEvictPerNamespace: 1
    maxNoOfPodsToEvictTotal: 1
    highNodeUtilization:
      numberOfNodes: 1
      thresholds:
        cpu: 25
        memory: 25
        pods: 25
```

### Limit descheduler activity to a node pool

Wildcard values are expanded against node labels observed in the cluster. This example considers node pools whose label begins with `batch-`. The selector scopes descheduler analysis; add equivalent node affinity to the workloads if replacement Pods must stay in these pools.

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterCompactionPolicy
metadata:
  name: batch-pool-compaction
spec:
  scope:
    namespaceSelector:
      operator: In
      values: [batch]
    labelSelector:
      matchLabels:
        compaction.kubex.ai/enabled: "true"
    workloadTypes: [Deployment, StatefulSet]
  scheduler:
    useKubexScheduler: true
  descheduler:
    enabled: true
    nodeSelector:
      matchExpressions:
        - key: cloud.google.com/gke-nodepool
          operator: In
          values: ["batch-*"]
    highNodeUtilization:
      thresholds:
        cpu: 40
        memory: 40
        pods: 30
```

### Use more aggressive consolidation

This example permits nodes carrying up to 60% requested CPU and memory to become sources, runs every 15 minutes, and allows more evictions per run. Use values like these only after validating PodDisruptionBudgets and scheduling constraints.

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterCompactionPolicy
metadata:
  name: production-workers-aggressive
spec:
  scope:
    namespaceSelector:
      operator: In
      values: [production]
    labelSelector:
      matchLabels:
        app.kubernetes.io/tier: worker
        compaction.kubex.ai/enabled: "true"
    workloadTypes: [Deployment]
  scheduler:
    useKubexScheduler: true
  descheduler:
    enabled: true
    interval: "*/15 * * * *"
    maxNoOfPodsToEvictPerNode: 2
    maxNoOfPodsToEvictPerNamespace: 4
    maxNoOfPodsToEvictTotal: 6
    highNodeUtilization:
      numberOfNodes: 0
      thresholds:
        cpu: 60
        memory: 60
        pods: 50
```

## Notes

- Set `spec.enabled: false` when you want to keep the object without letting it participate in selection.
- The scheduler is a dedicated Kubex-managed scheduler when `spec.scheduler.useKubexScheduler=true`; otherwise Kubex only targets the named external scheduler.
- Scheduler modes:
  - `useKubexScheduler: true` -> Kubex-managed scheduler `kubex-compaction-scheduler`
  - `useKubexScheduler: false` and `externalSchedulerName: <name>` -> external scheduler targeting only
  - `useKubexScheduler: false` and `externalSchedulerName: ""` -> descheduler-only compaction
- Policy status records whether the policy is enabled, the resolved scheduler name, and the expected scheduler/descheduler readiness state.
- The descheduler policy uses the effective policy label selector implicitly by default; `spec.descheduler.defaultEvictor.labelSelector` adds to that selector and `spec.descheduler.nodeSelector` narrows the policy to matching nodes.
- Starting image versions in this implementation:
  - scheduler: `registry.k8s.io/kube-scheduler:<cluster-version>` by default
  - descheduler: `registry.k8s.io/descheduler/descheduler:v0.36.0`
- Set `compactionScheduler.image.tag` or `.digest` to use an explicitly mirrored scheduler image; otherwise the controller derives the scheduler tag from the cluster Kubernetes version.
- Scheduler/descheduler pull policies, resources, security contexts, and chart-level `imagePullSecrets` are propagated to controller-created runtime Pods.
- Suppression blocks runtime replacement and scheduled descheduler eviction; it does not disable workload participation in the scheduler for future Pods.
- The controller reconciles the scheduler ConfigMap and full Pod runtime settings when active policies use the Kubex-managed scheduler.
- External scheduler mode is workload targeting only; Kubex does not manage scheduler runtime/config for those policies.
- The compaction scheduler ConfigMap is a fixed name: `kubex-compaction-scheduler-config`.
- The controller also reads `COMPACTION_DESCHEDULER_*` settings from its Deployment and creates one descheduler CronJob/ConfigMap per active descheduler policy using the fixed `kubex-compaction-descheduler` prefix.
- A policy with `spec.descheduler.enabled: true` but no managed workloads gets a suspended descheduler CronJob.
- With `openshift.enabled=true`, controller-created scheduler and descheduler Pods use arbitrary-UID-compatible restricted security contexts. Standard Kubernetes defaults remain unchanged when the switch is false or omitted.
