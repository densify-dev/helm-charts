# Frequently Asked Questions (FAQ)

Common questions and answers about Kubex Automation Controller deployment, configuration, and operation.

# Quick Links

- [Frequently Asked Questions (FAQ)](#frequently-asked-questions-faq)
- [Quick Links](#quick-links)
- [Getting Started Questions](#getting-started-questions)
- [Configuration Questions](#configuration-questions)
- [Security \& Safety Questions](#security--safety-questions)
- [Performance Questions](#performance-questions)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage Questions](#advanced-usage-questions)

---

## Getting Started Questions

### Q: What are the minimum requirements to run Kubex Automation Controller?
**A:** You need:
- Kubernetes cluster 1.19+ with admin access
- Helm 3.0+
- At least 2 CPU cores and 4GB RAM available across nodes
- Valid Kubex UI credentials and instance access
- TLS certificate management (cert-manager recommended)
- **Persistent storage**: Available StorageClass with at least 10Gi capacity for Valkey cache

### Q: How long does initial deployment take?
**A:** Typically 5-10 minutes:
- 2-3 minutes for Helm deployment
- 2-5 minutes for certificate generation (if using cert-manager)
- 1-2 minutes for pods to be running and ready

### Q: Do I need to install anything on worker nodes?
**A:** No, Kubex Automation Controller is deployed entirely as Kubernetes workloads. No node agents or DaemonSets are required.

### Q: What storage do I need to configure?
**A:** Valkey cache requires persistent storage:
- **StorageClass**: Configure in `valkey.storage.className` (e.g., `gp2` for EKS, `azurefile` for AKS, `standard` for GKE)
- **Capacity**: Default 10Gi, configurable via `valkey.storage.requestedSize`
- **CSI Drivers**: Most managed Kubernetes services include required drivers by default
- **Verify availability**: `kubectl get storageclass` to see available options

### Q: What's the recommended way to test this?
**A:** We strongly recommend starting with a dev/test cluster first:

1. **Start Small**: Begin with a single, non-critical namespace
2. **Base Policy**: Use the base optimization policy (allows all optimizations except memory limit downsizing)
3. **Gain Confidence**: Monitor behavior for several days to understand the automation patterns
4. **Gradual Expansion**: Slowly increase scope to additional namespaces as comfort grows
5. **Customize Policies**: Once confident, customize policies for specific workload requirements

This phased approach helps you learn the system behavior before broader deployment.

### Q: Can I test this safely in production?
**A:** Yes, but follow the same graduated approach as testing environments:

1. **Start Conservative**: Begin with the base optimization policy (allows all optimizations except memory limit downsizing)
2. **Single Namespace**: Test with one low-risk namespace initially  
3. **Exclude Critical Services**: Use namespace exclusions for mission-critical workloads
4. **Monitor Closely**: Watch automation behavior for at least a week before expanding
5. **Gradual Rollout**: Incrementally add namespaces and customize policies as confidence builds

The controller includes extensive safety checks, but a methodical rollout reduces risk.

---

## Configuration Questions

### Q: What's the difference between scope and policy?
**A:** 
- **Scope**: Defines *which* pods are eligible for automation (namespace and label filters)
- **Policy**: Defines *how* automation behaves (upsize/downsize rules, safety limits)

A scope references a policy by name, allowing you to apply different automation behaviors to different parts of your cluster.

### Q: Can I exclude specific applications from automation?
**A:** Yes, several ways:
- **Namespace exclusion**: Use `NotIn` operator in scope configuration
- **Label exclusion**: Add `podLabels` filters to exclude specific apps
- **Policy exclusion**: Set `allowedPodOwners` to exclude certain resource types

### Q: How do I safely test policy changes?
**A:** We recommend using Helm upgrades for all configuration changes:

1. **Recommended approach**: Use `helm upgrade` for both policy and scope changes to ensure consistency
2. **Quick testing**: For rapid policy iteration, you can edit the ConfigMap directly (takes effect in ~60 seconds)
3. **Scope changes**: Must always use `helm upgrade` - ConfigMap edits won't work for scope changes
4. **Test first**: Use non-production namespaces for initial validation

**Note**: ConfigMap edits are useful for quick policy testing but should be followed by a proper Helm upgrade to maintain infrastructure-as-code practices.

### Q: What happens if I have multiple policies that match the same pod?
**A:** The controller handles scope overlap with these behaviors:

- **Forced evictions**: The controller detects scope overlap and **takes no action** in performing forced pod evictions to prevent conflicting automation
- **Natural restarts**: If a pod restarts on its own, the mutating webhook will trigger and apply optimizations from **all matching policies**
- **Tracking mutations**: Pods receive a `mutated-by-policies` annotation listing all policy names that were applied during mutation
- **Monitoring**: Check logs for "scope overlap" warnings and refine your scope definitions to avoid unintended interactions

**Best practice**: Design scopes to be mutually exclusive to ensure predictable automation behavior.

---

## Security & Safety Questions

### Q: What permissions does the controller need?
**A:** Cluster-wide permissions including:
- **Read access**: All namespaces, nodes, quotas, limitranges
- **Write access**: Pods and pod eviction only
- **Secrets access**: Limited to kubex namespace only (for certificates and configuration)
- **No access**: Secrets in other namespaces, other workload types (unless pod eviction)

See [RBAC Guide](./RBAC-Guide.md) for complete details.

### Q: Can the controller damage my cluster, its control plane or system components?

**A:** Multiple safety mechanisms prevent damage:

- **System namespaces exclusion**: by default, the well-known system namespaces (`kube-system`, `kube-public`, `kube-node-lease`) are excluded from automation. Even if the [Scope Definition](./Configuration-Reference.md#scope-definition-manual-input) includes these namespaces (as in the following example), they will be excluded:

```yaml
scope:
  - name: everything
    policy: some-optimization
    namespaces:
      operator: NotIn
      values:
        - some-namespace
    podLabels:
    ...
```

- **Policies' allowed pod owners** - in each policy, the [Allowed Pod Owners](./Policy-Configuration.md#allowed-pod-owners) parameter specifies to which kinds of pod owners the policy applies. A common practice is to exclude `DaemonSet` from this comma-separated list, unless you have a very explicit reason to include it.

### Q: Can the controller damage my applications?
**A:** Multiple safety mechanisms prevent damage:
- **HPA awareness**: Won't resize if HPA is actively scaling on CPU and/or memory
- **PodDisruptionBudget**: Respects PDB constraints before eviction
- **ResourceQuota checking**: Ensures changes don't violate quotas
- **LimitRange validation**: Checks namespace limits before applying changes
- **Dry-run eviction**: Tests eviction safety before proceeding

### Q: What if I need to disable automation quickly?
**A:** Two methods:
- **Recommended**: Set `policy.automationEnabled: false` and run `helm upgrade`
- **Emergency**: Scale both components to 0 replicas:
  ```bash
  kubectl scale deployment kubex-automation-controller -n kubex --replicas=0
  kubectl scale deployment kubex-webhook -n kubex --replicas=0
  ```

### Q: Does this work with GitOps?
**A:** Yes! Configure your GitOps tool to ignore resource request/limit changes. See [GitOps Integration Guide](./GitOps-Integration.md) for Argo CD, Flux, and OpenShift GitOps.

---

## Performance Questions

### Q: How many pods can the controller handle?
**A:** Tested with clusters up to 5,000 pods. Performance depends on:
- **Pod scan interval**: How often the controller checks all pods
- **Eviction cooldown**: Wait time between pod evictions
- **Cluster API performance**: Controller makes many API calls

See [Pod Scan Configuration](./Pod-Scan-Configuration.md) for optimization guidelines.

### Q: Will this impact my cluster's API server?
**A:** The controller is designed to be API-friendly:
- **Efficient queries**: Uses label selectors and field selectors
- **Caching**: Stores recommendations in Valkey cache
- **Rate limiting aware**: Handles 429 responses gracefully
- **Configurable intervals**: Adjust scan frequency for your cluster size

### Q: How much additional resource usage should I expect?
**A:** Default resource allocation:
- **Controller pod**: 250m CPU, 256Mi memory (increase for large clusters)
- **Webhook pod**: 100m CPU, 64Mi memory  
- **Valkey cache**: 250m CPU, 256Mi memory
- **Storage**: 10Gi persistent volume for Valkey

### Q: Can I optimize the Kubex components themselves?
**A:** Yes! As an automation solution, Kubex cannot automate its own components, so you should manually optimize based on Kubex recommendations:

1. **Monitor in Densify**: Check recommendations for `kubex-automation-controller`, `kubex-webhook`, and `kubex-valkey` pods
2. **Override resources** in your `kubex-automation-values.yaml`:
```yaml
deployment:
  webhookResources:  # Resource Specs for the webhook server container
    requests:
      memory: "128Mi"  # Adjust based on Kubex recommendations
      cpu: "200m"
    limits:
      memory: "256Mi"  # Adjust based on Kubex recommendations
  gatewayResources:  # CPU and memory resource requests and limits for the container
    requests:
      memory: "256Mi"  # Adjust based on Kubex recommendations
      cpu: "500m"
    limits:
      memory: "512Mi"  # Adjust based on Kubex recommendations
  controllerResources:  # Resource Specs for the controller container
    requests:
      memory: "256Mi"  # Adjust based on Kubex recommendations
      cpu: "500m"
    limits:
      memory: "1Gi"    # Adjust based on Kubex recommendations

valkey:
  resources:  # Resource sizing (tune for your cluster/workload)
    requests:
      cpu: "500m"      # Adjust based on Kubex recommendations
      memory: "512Mi"  # Adjust based on Kubex recommendations
    limits:
      memory: "1Gi"    # Adjust based on Kubex recommendations
```
3. **Apply changes**: Run `helm upgrade kubex-automation-controller densify/kubex-automation-controller -f kubex-automation-values.yaml`

### Q: How do I prevent too many pod evictions during large-scale optimization?
**A:** Use eviction throttling to control the rate of pod evictions across your cluster:

```yaml
deployment:
  controllerEnv:
    evictionThrottlingWindow: "6h"     # Time window for counting evictions
    evictionThrottlingMax: "1000"      # Max evictions allowed in the window
```

**When to use eviction throttling:**
- **Large cluster initial deployment**: Prevent overwhelming cluster during first automation run
- **Production environments**: Limit impact during business hours
- **Rolling updates**: Control eviction rate during major application changes
- **Infrastructure protection**: Prevent cascading failures from too many simultaneous changes

**Example scenarios:**
- **Conservative**: 500 evictions per 24 hours for very large production clusters
- **Moderate**: 1000 evictions per 6 hours for typical production deployments  
- **Aggressive**: 2000 evictions per 3 hours for development/testing environments

The controller will pause evictions when the limit is reached and resume when the time window resets.

---

## Troubleshooting

### Q: I'm having issues with deployment, pod optimization, or certificate problems. Where should I look?
**A:** For comprehensive troubleshooting guidance, see our dedicated [Troubleshooting Guide](./Troubleshooting.md). It covers:

- **Initial deployment issues**: Pod startup problems, image pull errors, resource constraints
- **Pod optimization problems**: Why pods aren't being optimized, policy restrictions, safety blocks
- **Webhook issues**: Certificate problems, service connectivity, scope mismatches  
- **Certificate troubleshooting**: Custom certificate requirements, CA bundle issues, DNS name validation
- **Storage problems**: Valkey deployment issues, StorageClass configuration, PVC binding
- **Performance issues**: Resource usage monitoring, API rate limiting, processing bottlenecks
- **Configuration debugging**: YAML validation, ConfigMap verification, debug mode activation
- **Emergency procedures**: Quick automation disable, configuration reset

The troubleshooting guide includes step-by-step diagnostic commands and solutions for each scenario.

---

## Advanced Usage Questions

### Q: Can I run multiple instances for high availability?
**A:** Yes:
```yaml
deployment:
  replicas:
    controller: 2      # Multiple controllers with leader election
    webhookServer: 3   # Multiple webhook instances
```

### Q: Can I customize which resource types are automated?
**A:** Yes, via policy configuration:
```yaml
policy:
  policies:
    my-policy:
      allowedPodOwners: "Deployment,StatefulSet,DaemonSet"  # Add/remove as needed
```

### Q: How do I handle large clusters (>2000 pods)?
**A:** 
1. **Optimize scan timing**: See [Pod Scan Configuration](./Pod-Scan-Configuration.md)
2. **Increase resources**: More CPU/memory for controller
3. **Use node scheduling**: Deploy to high-performance nodes
4. **Consider phased rollout**: Start with subset of namespaces

### Q: Can I use this with custom resources (CRDs)?
**A:** The controller works with pods regardless of their owner. If your CRD creates pods, those pods can be optimized. Add your CRD kind to `allowedPodOwners` if needed.

---

**Still have questions?** Check our [Troubleshooting Guide](./Troubleshooting.md) or review the [Configuration Reference](./Configuration-Reference.md) for detailed information.