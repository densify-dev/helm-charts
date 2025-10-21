# Pod Scan Configuration Guide

## Overview

For clusters with many pods, you need to adjust scan timing to ensure the controller has enough time to process all pods. This guide provides pre-calculated values based on your cluster size.

## Quick Setup

**Step 1**: Count your pods
```bash
kubectl get pods --all-namespaces | wc -l
```

**Step 2**: Choose your configuration from the tables below

**Step 3**: Update your `kubex-automation-values.yaml` and run `helm upgrade`

> **Note**: Default settings are optimized for 1000 pods initial deployment with 1m cooldown. For different cluster sizes, use the tables below.

## Pod Eviction Cooldown Period

The `podEvictionCooldownPeriod` controls the wait time between individual pod evictions:

- **Default: 1m** - Allows time for resource quota checks and termination grace periods
- **Aggressive: 10-15s** - For faster resizing when cluster conditions allow
- **Conservative: 2-5m** - Use longer cooldowns when you have:
  - Large container images with no image cache
  - Heavy cluster load or slow API server responses
  - Complex termination procedures

## When Do You Need This?

- **Most clusters (≤1000 pods)**: Default settings work well for initial deployment
- **Large clusters (>1000 pods)**: Use the configurations below for optimal performance
- **Very large clusters (>2000 pods)**: Consider phased deployment during maintenance windows

## Configuration Tables

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

## Cooldown Period Guide

**10s cooldown**: Faster processing, but creates more cluster load during pod evictions
**30s cooldown**: Slower but safer for cluster stability (recommended default)

**Recommendation**: Use 30s for most clusters. Only use 10s if you need faster processing and can handle higher cluster load.

## How to Apply Configuration

1. **Find your pod count** in the tables above
2. **Copy the configuration** that matches your cluster size and deployment phase  
3. **Add to your kubex-automation-values.yaml**:

```yaml
deployment:
  controllerEnv:
    podScanInterval: "6h45m"           # Example: 1000 pods initial deployment
    podScanTimeout: "6h30m"            # Example: 1000 pods initial deployment
    podEvictionCooldownPeriod: "30s"   # Recommended default
```

4. **Apply the changes**:
```bash
helm upgrade kubex-automation-controller densify/kubex-automation-controller -n kubex -f kubex-automation-values.yaml
```

## Troubleshooting

**Seeing timeout errors?** Increase your `podScanTimeout` by 50%

**Scans taking too long?** 
- Use 10s cooldown instead of 30s
- Consider deploying during maintenance windows for large clusters

**High cluster load during automation?** 
- Increase `podEvictionCooldownPeriod` to 30s or 60s
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