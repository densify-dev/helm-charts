# Rollback Policies

Rollback policies enable health monitoring and automatic rollback after failed resizes.

Use them when you want the controller to monitor workloads after a resize is applied and automatically restore the last known good state if health checks fail.

**Important**: Without a matching rollback policy, the controller will not monitor, rollback, or retry failed resizes. The rollback mechanism is disabled by default until you create a policy.

## Scope Mapping

- `RollbackPolicy` is namespaced and applies to workloads within a single namespace.
- `ClusterRollbackPolicy` is cluster-scoped and can apply across multiple namespaces using namespace selectors.

## Field Reference

## `RollbackPolicy.spec`

| Field | Default | Description |
| --- | --- | --- |
| `spec.scope` | none | Optional scope object for workload selection within the namespace. |
| `spec.scope.labelSelector` | none | Kubernetes label selector for matching workloads. |
| `spec.scope.workloadTypes` | `[Deployment, StatefulSet, CronJob, Rollout, Job, AnalysisRun, DaemonSet]` | Workload kinds this policy applies to. Default excludes `StrimziPodSet` (opt-in only). |
| `spec.monitoringPeriod` | none (required) | How long the controller observes an active resize attempt before declaring failure. Example: `5m`, `10m`. |
| `spec.rollbackTarget` | none (required) | Whether rollback returns to `manifest` resources or `lastSuccessful` state. |
| `spec.adoptionThresholdPercent` | none (required) | Percentage of the workload cohort that must adopt the target resources successfully (1-100). |
| `spec.backoff.timePeriod` | none (required) | Base duration for a rollback turn. Example: `1m`, `5m`. |
| `spec.backoff.multiplyByTurn` | none (required) | Scales the base duration by the current turn number. Example: with `timePeriod: 1m` and `multiplyByTurn: 2`, turn 1 waits 2m and turn 2 waits 4m. |
| `spec.backoff.maxAttempts` | none (required) | Maximum number of turns before the controller marks the rollback as permanently failed. |
| `spec.weight` | `0` | Higher weight wins when multiple rollback policies match. When weights are equal, older policies win. |

## `ClusterRollbackPolicy.spec`

| Field | Default | Description |
| --- | --- | --- |
| `spec.scope.labelSelector` | none | Kubernetes label selector for matching workloads. |
| `spec.scope.workloadTypes` | `[Deployment, StatefulSet, CronJob, Rollout, Job, AnalysisRun, DaemonSet]` | Workload kinds this policy applies to. Default excludes `StrimziPodSet` (opt-in only). |
| `spec.scope.namespaceSelector.operator` | none | Namespace selector operator: `In` or `NotIn`. |
| `spec.scope.namespaceSelector.values` | none | Namespace patterns to include or exclude (supports `*` wildcards, e.g. `"prod-*"`). Wildcard patterns must be enclosed in double quotes. |
| `spec.monitoringPeriod` | none (required) | How long the controller observes an active resize attempt before declaring failure. Example: `5m`, `10m`. |
| `spec.rollbackTarget` | none (required) | Whether rollback returns to `manifest` resources or `lastSuccessful` state. |
| `spec.adoptionThresholdPercent` | none (required) | Percentage of the workload cohort that must adopt the target resources successfully (1-100). |
| `spec.backoff.timePeriod` | none (required) | Base duration for a rollback turn. Example: `1m`, `5m`. |
| `spec.backoff.multiplyByTurn` | none (required) | Scales the base duration by the current turn number. Example: with `timePeriod: 1m` and `multiplyByTurn: 2`, turn 1 waits 2m and turn 2 waits 4m. |
| `spec.backoff.maxAttempts` | none (required) | Maximum number of turns before the controller marks the rollback as permanently failed. |
| `spec.weight` | `0` | Higher weight wins when multiple rollback policies match. When weights are equal, older policies win. |

## Example: Namespaced Rollback Policy

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: RollbackPolicy
metadata:
  name: production-rollback
  namespace: production
spec:
  scope:
    labelSelector:
      matchLabels:
        app.kubernetes.io/part-of: storefront
      matchExpressions:
        - key: tier
          operator: In
          values:
            - api
            - worker
    workloadTypes:
      - Deployment
      - StatefulSet
  monitoringPeriod: 5m
  rollbackTarget: lastSuccessful
  adoptionThresholdPercent: 80
  backoff:
    timePeriod: 1m
    multiplyByTurn: 2
    maxAttempts: 3
  weight: 100
```

## Example: Cluster Rollback Policy

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterRollbackPolicy
metadata:
  name: production-cluster-rollback
spec:
  scope:
    namespaceSelector:
      operator: In
      values:
        - "prod-*"
        - "staging"
    labelSelector:
      matchLabels:
        rollback-enabled: "true"
    workloadTypes:
      - Deployment
      - StatefulSet
      - CronJob
  monitoringPeriod: 10m
  rollbackTarget: lastSuccessful
  adoptionThresholdPercent: 90
  backoff:
    timePeriod: 2m
    multiplyByTurn: 3
    maxAttempts: 5
  weight: 50
```

## Rollback Target Options

### `lastSuccessful`

Restores the last known successful resource settings that the controller recorded when monitoring succeeded. This allows the controller to restore intermediate values that worked, rather than going all the way back to the original manifest.

Use when you want to preserve incremental progress from successful resizes.

### `manifest`

Restores the original resource settings defined in the workload manifest. This ignores any intermediate successful states and returns directly to the baseline.

Use when you want predictable, deterministic rollback behavior that always returns to the manifest values.

## Adoption Threshold

The `adoptionThresholdPercent` field determines what percentage of the workload cohort (e.g., all pods in a Deployment) must successfully adopt the target resources before monitoring is considered successful.

- Setting `80` means at least 80% of pods must be healthy with the new resource settings
- This helps detect partial failures where only some pods fail health checks
- Range: 1-100

## Backoff Turn Calculation

The backoff wait time is calculated as:

```
wait_time = timePeriod * multiplyByTurn * current_turn
```

Example with `timePeriod: 1m` and `multiplyByTurn: 2`:

- Turn 1: `1m * 2 * 1 = 2m`
- Turn 2: `1m * 2 * 2 = 4m`
- Turn 3: `1m * 2 * 3 = 6m`

After `maxAttempts` turns are exhausted, the rollback moves to `failedPermanent` and the controller stops retrying.

## Notes

- Use namespaced rollback policies when teams own their own namespaces and want namespace-specific rollback behavior.
- Use cluster rollback policies when you want consistent rollback behavior across multiple namespaces or the entire cluster.
- When multiple rollback policies of the same kind match, higher `weight` wins, then older objects win on ties.
- For behavioral details and operational expectations, see [Rollback Backoff](./Rollback-Backoff.md).
- Rollback policies are independent of automation strategies and proactive/static policies - they work alongside those policies to add health monitoring and automatic rollback capabilities.
