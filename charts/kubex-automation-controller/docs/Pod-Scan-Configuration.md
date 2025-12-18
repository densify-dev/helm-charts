# Pod Scan Configuration

Use this guide to tune scan cadence and eviction controls without duplicating information across modes.

## Determine Your Mode

| Requirement | In-Place (default) | Pod Eviction |
|-------------|--------------------|--------------|
| Kubernetes version | ≥ 1.33 | < 1.33 |
| Policy flag | `inPlaceResize.enabled: true` | `inPlaceResize.enabled: false` |
| Behavior | Live resource patching | Evict + recreate pods |

Count pods cluster-wide for a quick estimate:

```bash
kubectl get pods --all-namespaces | wc -l
```

> For tighter sizing, repeat the count per namespace or selector that matches your automation scopes.

## In-Place Mode Settings

Default values cover most clusters up to 5000 pods:

```yaml
deployment:
  controllerEnv:
    podScanInterval: "1h"
    podScanTimeout: "30m"
    podEvictionCooldownPeriod: "1m"  # only used when falling back to eviction
```

Adjust only for scale-related API latency:

- 1000-2000 pods → timeout 45m, interval 1h
- 2000-5000 pods → timeout 1h, interval 1h15m
- 5000+ pods → timeout 1h30m, interval 2h

## Pod Eviction Mode Settings

Use when Kubernetes < 1.33 or the policy disables in-place resizing. Evictions require a cooldown to respect termination grace periods, quotas, and scheduling limits.

- 15s cooldown: aggressive, higher API and scheduler load
- 1m cooldown: default balance
- 3m cooldown: conservative for slow storage, large images, or overloaded clusters

### Initial Rollout (many pods change)

| Pods | 15s cooldown | 1m cooldown | 3m cooldown |
|------|--------------|-------------|-------------|
| 100 | Timeout 15m, Interval 30m | Timeout 45m, Interval 1h | Timeout 1h15m, Interval 1h30m |
| 500 | 1h15m / 1h30m | 3h20m / 3h35m | 8h45m / 9h |
| 1000 | 2h25m / 2h40m | 6h30m / 6h45m | 17h15m / 17h30m |
| 2000 | 4h45m / 5h | 12h55m / 13h10m | 34h15m / 34h30m |
| 5000 | 11h45m / 12h | 31h15m / 31h30m | Use eviction throttling |

### Steady State (fewer pods change)

| Pods | 15s cooldown | 1m cooldown | 3m cooldown |
|------|--------------|-------------|-------------|
| 100 | Timeout 10m, Interval 25m | 15m / 30m | 30m / 45m |
| 500 | 30m / 45m | 1h / 1h15m | 2h45m / 3h |
| 1000 | 55m / 1h10m | 1h55m / 2h10m | 5h20m / 5h35m |
| 2000 | 1h45m / 2h | 3h45m / 4h | 10h30m / 10h45m |
| 5000 | 4h15m / 4h30m | 9h20m / 9h35m | Use eviction throttling |

### Applying Changes

```yaml
deployment:
  controllerEnv:
    podScanInterval: "6h45m"
    podScanTimeout: "6h30m"
    podEvictionCooldownPeriod: "1m"
```

```bash
helm upgrade kubex-automation-controller densify/kubex-automation-controller -n kubex -f kubex-automation-values.yaml
```

## Troubleshooting

- Timeouts: raise `podScanTimeout` by ~50%
- Too many API calls: lengthen `podScanInterval`
- Eviction backlog: increase cooldown or enable throttling

## Eviction Throttling

```yaml
deployment:
  controllerEnv:
    evictionThrottlingWindow: "6h"
    evictionThrottlingMax: "1000"
```

Use 500/24h for conservative production, 1000/6h for typical prod, 2000/3h for dev and testing.