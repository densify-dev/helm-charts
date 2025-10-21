# Advanced Configuration Guide

This guide covers advanced configuration options for the Kubex Automation Controller including node scheduling, performance tuning, and enterprise features.

# Quick Links

- [Advanced Configuration Guide](#advanced-configuration-guide)
- [Quick Links](#quick-links)
- [Node Scheduling Configuration](#node-scheduling-configuration)
  - [Configuring Node Affinity](#configuring-node-affinity)
  - [Common Scheduling Patterns](#common-scheduling-patterns)
- [Performance Optimization](#performance-optimization)
  - [Resource Sizing](#resource-sizing)
  - [Pod Scan Configuration](#pod-scan-configuration)
  - [Valkey Cache Tuning](#valkey-cache-tuning)
- [Enterprise Features](#enterprise-features)
  - [High Availability Setup](#high-availability-setup)
  - [Monitoring Integration](#monitoring-integration)
  - [Security Hardening](#security-hardening)

---

## Node Scheduling Configuration

The Kubex Automation Controller supports advanced node scheduling options to control where controller and webhook pods are deployed. This is useful for:

- **Cost Optimization**: Deploy to spot/preemptible instances for non-critical components
- **Performance**: Target high-performance nodes for better response times
- **Security**: Use dedicated node pools with specific security configurations
- **Resource Isolation**: Separate system components from application workloads

### Configuring Node Affinity

Add the following sections to your `kubex-automation-values.yaml` to configure node scheduling:

```yaml
deployment:
  # Node scheduling for controller deployment
  controller:
    nodeSelector:
      node-pool: system  # Example: target specific node pool
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: kubernetes.io/instance-type
              operator: In
              values: ["m5.large", "m5.xlarge"]
    tolerations:
    - key: "system-workloads"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
    topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels:
          app: kubex-controller
  
  # Node scheduling for webhook deployment
  webhook:
    nodeSelector:
      node-pool: system
    affinity:
      nodeAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          preference:
            matchExpressions:
            - key: node-type
              operator: In
              values: ["stable"]
    tolerations:
    - key: "system-workloads"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
```

### Common Scheduling Patterns

**Deploy to System Node Pool:**
```yaml
deployment:
  controller:
    nodeSelector:
      node-pool: system
  webhook:
    nodeSelector:
      node-pool: system
```

**Avoid Spot Instances:**
```yaml
deployment:
  controller:
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: node.kubernetes.io/instance-type
              operator: NotIn
              values: ["spot"]
```

**Tolerate System Taints:**
```yaml
deployment:
  controller:
    tolerations:
    - key: "CriticalAddonsOnly"
      operator: "Exists"
    - key: "node-role.kubernetes.io/control-plane"
      operator: "Exists"
      effect: "NoSchedule"
```

## Performance Optimization

### Resource Sizing

Adjust resource requests and limits based on your cluster size:

```yaml
deployment:
  controllerResources:
    requests:
      memory: "256Mi"  # Increase for large clusters
      cpu: "500m"      # Increase for heavy processing
    limits:
      memory: "1Gi"    # Set appropriate limits
  
  webhookResources:
    requests:
      memory: "128Mi"  # Webhook is lighter weight
      cpu: "200m"
    limits:
      memory: "512Mi"
```

### Pod Scan Configuration

For detailed performance tuning, see: **[Pod Scan Configuration Guide](./Pod-Scan-Configuration.md)**

### Eviction Throttling

Control the rate of pod evictions to maintain cluster stability during large-scale enforcement:

```yaml
deployment:
  controllerConfig:
    # Throttle evictions over a time window
    evictionThrottlingWindow: "6h"    # Time window for throttling
    evictionThrottlingMax: "1000"     # Max evictions in window
```

**When to Use:**
- **Large Clusters:** Prevent overwhelming the cluster scheduler
- **Production Environments:** Maintain service availability during enforcement
- **Rolling Updates:** Control disruption during policy changes

**Example Scenarios:**
```yaml
# Conservative throttling for mission-critical clusters
evictionThrottlingWindow: "12h"
evictionThrottlingMax: "500"

# Aggressive throttling for large-scale deployments
evictionThrottlingWindow: "4h"
evictionThrottlingMax: "2000"
```

### Valkey Cache Tuning

Optimize cache performance for your workload:

```yaml
valkey:
  resources:
    requests:
      cpu: "250m"
      memory: "512Mi"  # Increase for more caching
    limits:
      memory: "1Gi"
  
  storage:
    requestedSize: "20Gi"  # Larger storage for persistent cache
    className: "fast-ssd"  # Use high-performance storage
```

## Enterprise Features

### High Availability Setup

Configure multiple replicas for production environments:

```yaml
deployment:
  replicas:
    controller: 2      # Multiple controller instances
    webhookServer: 3   # Multiple webhook instances for availability
    
  # Enable leader election for controllers
  controllerEnv:
    leaderElection: "true"
```

### Monitoring Integration

Enable metrics collection:

```yaml
valkey:
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true  # For Prometheus Operator
      
deployment:
  # Enable additional monitoring
  controllerEnv:
    metricsEnabled: "true"
    metricsPort: "8080"
```

### Security Hardening

Additional security configurations:

```yaml
deployment:
  # Security contexts
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
    fsGroup: 65534
    
  # Network policies
  networkPolicies:
    enabled: true
    
  # Pod security standards
  podSecurityStandards:
    enforce: "restricted"
```