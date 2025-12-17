# Pod Scan Configuration Guide

## Overview

This guide helps you configure pod scan timing based on your cluster size and Kubernetes version.

**Important**: Configuration differs significantly depending on your resizing mode:

- **In-Place Resizing Mode** (Kubernetes 1.33+, default): Fast resizing without pod evictions
- **Pod Eviction Mode** (Kubernetes < 1.33 or policy `inPlaceResize.enabled: false`): Requires pod evictions with cooldown periods

## Resizing Mode Detection

The controller automatically uses in-place resizing when:
- ✅ Kubernetes version is 1.33 or higher
- ✅ Policy has `inPlaceResize.enabled: true` (default)

It falls back to pod eviction mode when:
- ⚠️ Kubernetes version is below 1.33
- ⚠️ Policy has `inPlaceResize.enabled: false`

## Quick Setup

**Step 1**: Count your pods
```bash
kubectl get pods --all-namespaces | wc -l
```

**Step 2**: Choose your configuration from the tables below

**Step 3**: Choose the appropriate configuration table based on your resizing mode

**Step 4**: Update your `kubex-automation-values.yaml` and run `helm upgrade`

> **Note**: Default settings are optimized for in-place resizing mode (Kubernetes 1.33+). If using pod eviction mode, see tables below.

## Configuration by Resizing Mode

### In-Place Resizing Mode (Kubernetes 1.33+, Default)

**How it works**: Pods are resized without eviction or restart. Much faster and safer.

**Recommended settings** (most clusters):
```yaml
deployment:
  controllerEnv:
    podScanInterval: "1h"              # Check for optimization opportunities hourly
    podScanTimeout: "30m"              # Plenty of time for API calls
    podEvictionCooldownPeriod: "1m"   # Only used as fallback
```

**For larger clusters** (>1000 pods), scale timeout and interval:
- **1000-2000 pods**: `podScanTimeout: "45m"`, `podScanInterval: "1h"`
- **2000-5000 pods**: `podScanTimeout: "1h"`, `podScanInterval: "1h15m"`
- **5000+ pods**: `podScanTimeout: "1h30m"`, `podScanInterval: "2h"`

**Note**: In-place resizing is fast, but API calls still take time for very large clusters.

### Pod Eviction Mode (Kubernetes < 1.33 or inPlaceResize.enabled: false)

**How it works**: Pods must be evicted and recreated to apply new resource settings. Requires cooldown periods.

**Pod Eviction Cooldown Period**:

The `podEvictionCooldownPeriod` controls the wait time between individual pod evictions:

- **Default: 1m** - Allows time for resource quota checks and termination grace periods
- **Aggressive: 10-15s** - For faster resizing when cluster conditions allow
- **Conservative: 2-5m** - Use longer cooldowns when you have:
  - Large container images with no image cache
  - Heavy cluster load or slow API server responses
  - Complex termination procedures

## When Do You Need Custom Configuration?

**In-Place Resizing Mode** (Kubernetes 1.33+):
- **Most clusters (≤5000 pods)**: Default settings work well
- **Very large clusters (>5000 pods)**: Set `podScanTimeout: "1h30m"` and `podScanInterval: "2h"`

**Pod Eviction Mode** (Kubernetes < 1.33 or policy inPlaceResize.enabled: false):
- **Most clusters (≤1000 pods)**: Default settings work for initial deployment  
- **Large clusters (>1000 pods)**: Use the configurations below for optimal performance
- **Very large clusters (>2000 pods)**: Consider phased deployment during maintenance windows

## Configuration Tables for Pod Eviction Mode

**Use these tables ONLY if:**
- Your Kubernetes version is below 1.33, OR
- Your policy has `inPlaceResize.enabled: false`

Choose based on your cluster size and deployment phase:

### First-Time Deployment (Most pods need optimization)

| Pod Count | 10-15s Cooldown (Aggressive) | 1m Cooldown (Default) | 2-5m Cooldown (Conservative) |
|-----------|------------------------------|------------------------|-------------------------------|
| **100 pods** | `podScanTimeout: "15m"`<br>`podScanInterval: "30m"`<br>`podEvictionCooldownPeriod: "15s"` | `podScanTimeout: "45m"`<br>`podScanInterval: "1h"`<br>`podEvictionCooldownPeriod: "1m"` | `podScanTimeout: "1h15m"`<br>`podScanInterval: "1h30m"`<br>`podEvictionCooldownPeriod: "3m"` |
| **500 pods** | `podScanTimeout: "1h15m"`<br>`podScanInterval: "1h30m"`<br>`podEvictionCooldownPeriod: "15s"` | `podScanTimeout: "3h20m"`<br>`podScanInterval: "3h35m"`<br>`podEvictionCooldownPeriod: "1m"` | `podScanTimeout: "8h45m"`<br>`podScanInterval: "9h"`<br>`podEvictionCooldownPeriod: "3m"` |
| **1000 pods** | `podScanTimeout: "2h25m"`<br>`podScanInterval: "2h40m"`<br>`podEvictionCooldownPeriod: "15s"` | `podScanTimeout: "6h30m"`<br>`podScanInterval: "6h45m"`<br>`podEvictionCooldownPeriod: "1m"` | `podScanTimeout: "17h15m"`<br>`podScanInterval: "17h30m"`<br>`podEvictionCooldownPeriod: "3m"` |
| **2000 pods** | `podScanTimeout: "4h45m"`<br>`podScanInterval: "5h"`<br>`podEvictionCooldownPeriod: "15s"` | `podScanTimeout: "12h55m"`<br>`podScanInterval: "13h10m"`<br>`podEvictionCooldownPeriod: "1m"` | `podScanTimeout: "34h15m"`<br>`podScanInterval: "34h30m"`<br>`podEvictionCooldownPeriod: "3m"` |
| **5000 pods** | `podScanTimeout: "11h45m"`<br>`podScanInterval: "12h"`<br>`podEvictionCooldownPeriod: "15s"` | `podScanTimeout: "31h15m"`<br>`podScanInterval: "31h30m"`<br>`podEvictionCooldownPeriod: "1m"` | Use eviction throttling instead |

### After Several Weeks (Fewer pods need changes)

| Pod Count | 10-15s Cooldown (Aggressive) | 1m Cooldown (Default) | 2-5m Cooldown (Conservative) |
|-----------|------------------------------|------------------------|-------------------------------|
| **100 pods** | `podScanTimeout: "10m"`<br>`podScanInterval: "25m"`<br>`podEvictionCooldownPeriod: "15s"` | `podScanTimeout: "15m"`<br>`podScanInterval: "30m"`<br>`podEvictionCooldownPeriod: "1m"` | `podScanTimeout: "30m"`<br>`podScanInterval: "45m"`<br>`podEvictionCooldownPeriod: "3m"` |
| **500 pods** | `podScanTimeout: "30m"`<br>`podScanInterval: "45m"`<br>`podEvictionCooldownPeriod: "15s"` | `podScanTimeout: "1h"`<br>`podScanInterval: "1h15m"`<br>`podEvictionCooldownPeriod: "1m"` | `podScanTimeout: "2h45m"`<br>`podScanInterval: "3h"`<br>`podEvictionCooldownPeriod: "3m"` |
| **1000 pods** | `podScanTimeout: "55m"`<br>`podScanInterval: "1h10m"`<br>`podEvictionCooldownPeriod: "15s"` | `podScanTimeout: "1h55m"`<br>`podScanInterval: "2h10m"`<br>`podEvictionCooldownPeriod: "1m"` | `podScanTimeout: "5h20m"`<br>`podScanInterval: "5h35m"`<br>`podEvictionCooldownPeriod: "3m"` |
| **2000 pods** | `podScanTimeout: "1h45m"`<br>`podScanInterval: "2h"`<br>`podEvictionCooldownPeriod: "15s"` | `podScanTimeout: "3h45m"`<br>`podScanInterval: "4h"`<br>`podEvictionCooldownPeriod: "1m"` | `podScanTimeout: "10h30m"`<br>`podScanInterval: "10h45m"`<br>`podEvictionCooldownPeriod: "3m"` |
| **5000 pods** | `podScanTimeout: "4h15m"`<br>`podScanInterval: "4h30m"`<br>`podEvictionCooldownPeriod: "15s"` | `podScanTimeout: "9h20m"`<br>`podScanInterval: "9h35m"`<br>`podEvictionCooldownPeriod: "1m"` | Use eviction throttling instead |

## Cooldown Period Guide (Pod Eviction Mode Only)

**Applies only when using pod eviction mode (Kubernetes < 1.33 or policy inPlaceResize.enabled: false)**

**15s cooldown**: Faster processing, but creates more cluster load during pod evictions
**1m cooldown**: Default, allows for resource quota checks and termination grace periods
**3m cooldown**: Conservative, safer for clusters with slow scheduling or large images

**Recommendation**: Use 1m for most clusters. Only use shorter cooldowns if you need faster processing and can handle higher cluster load.

## How to Apply Configuration

### For In-Place Resizing Mode (Kubernetes 1.33+)

**Most clusters need no changes** - defaults work well. Only customize for very large clusters:

```yaml
deployment:
  controllerEnv:
    podScanInterval: "2h"              # Increase for 5000+ pods
    podScanTimeout: "1h30m"            # Must be less than podScanInterval
    podEvictionCooldownPeriod: "1m"   # Used only as fallback
```

### For Pod Eviction Mode (Kubernetes < 1.33)

1. **Find your pod count** in the tables above
2. **Copy the configuration** that matches your cluster size and deployment phase  
3. **Add to your kubex-automation-values.yaml**:

```yaml
deployment:
  controllerEnv:
    podScanInterval: "6h45m"           # Example: 1000 pods initial deployment
    podScanTimeout: "6h30m"            # Example: 1000 pods initial deployment
    podEvictionCooldownPeriod: "1m"   # Recommended default
```

4. **Apply the changes**:
```bash
helm upgrade kubex-automation-controller densify/kubex-automation-controller -n kubex -f kubex-automation-values.yaml
```

## Troubleshooting

### In-Place Resizing Mode

**Seeing timeout errors?** Increase your `podScanTimeout` by 50%

**Want faster optimization?** Decrease `podScanInterval` to 30m (but not recommended below 15m)

**High API server load?** Increase `podScanInterval` to 2h or more

### Pod Eviction Mode

**Seeing timeout errors?** Increase your `podScanTimeout` by 50%

**Scans taking too long?** 
- Use 15s cooldown instead of 1m (if cluster can handle it)
- Consider deploying during maintenance windows for large clusters

**High cluster load during automation?** 
- Increase `podEvictionCooldownPeriod` to 2m or 3m
- Use eviction throttling to limit total evictions over time

## Eviction Throttling for Large Clusters

For very large clusters or production environments, you can limit the total number of pod evictions over a longer time period:

```yaml
deployment:
  controllerEnv:
    evictionThrottlingWindow: "6h"     # Time window for counting
    evictionThrottlingMax: "1000"      # Max evictions in window
```

**When to use eviction throttling:**
- **Very large clusters** (>2000 pods): Prevent infrastructure overload
- **Production safety**: Limit automation impact during business hours  
- **Rolling deployment coordination**: Control eviction rate during major updates

**Example configurations:**
- **Conservative**: 500 evictions per 24h for mission-critical production
- **Moderate**: 1000 evictions per 6h for typical production environments
- **Development**: 2000 evictions per 3h for faster testing cycles