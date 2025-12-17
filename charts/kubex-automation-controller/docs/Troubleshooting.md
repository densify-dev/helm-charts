# Troubleshooting Guide

This guide provides comprehensive guidance for diagnosing and resolving common issues with the Kubex Automation Controller.

# Quick Links

- [Troubleshooting Guide](#troubleshooting-guide)
- [Quick Links](#quick-links)
  - [Helm Upgrade Conflicts](#helm-upgrade-conflicts)
    - [MutatingWebhookConfiguration Ownership Conflicts](#mutatingwebhookconfiguration-ownership-conflicts)
  - [Initial Deployment Issues](#initial-deployment-issues)
    - [Check Pod Status](#check-pod-status)
    - [Common Deployment Problems](#common-deployment-problems)
  - [Controller Not Processing Pods](#controller-not-processing-pods)
    - [Verify Configuration](#verify-configuration)
    - [Common Controller Issues](#common-controller-issues)
      - [Pod Optimization Troubleshooting](#pod-optimization-troubleshooting)
  - [Webhook Not Mutating Pods](#webhook-not-mutating-pods)
    - [Check Webhook Configuration](#check-webhook-configuration)
    - [Common Webhook Issues](#common-webhook-issues)
      - [Certificate Issues with Custom Certificates](#certificate-issues-with-custom-certificates)
  - [Performance Issues](#performance-issues)
    - [Monitor Resource Usage](#monitor-resource-usage)
    - [Performance Indicators](#performance-indicators)
  - [Valkey Cache Issues](#valkey-cache-issues)
    - [Check Valkey Status](#check-valkey-status)
    - [Common Valkey Problems](#common-valkey-problems)
      - [Storage Troubleshooting](#storage-troubleshooting)
  - [Configuration Debugging](#configuration-debugging)
    - [Validate YAML Syntax](#validate-yaml-syntax)
    - [Check Resource References](#check-resource-references)
      - [Advanced Configuration Debugging](#advanced-configuration-debugging)
  - [Emergency Procedures](#emergency-procedures)
    - [Disable Automation Quickly](#disable-automation-quickly)
    - [Reset Configuration](#reset-configuration)
  - [Getting Help](#getting-help)
    - [Collect Diagnostics](#collect-diagnostics)
    - [Key Information to Provide](#key-information-to-provide)

---

## Helm Upgrade Conflicts

### MutatingWebhookConfiguration Ownership Conflicts

**Symptom:** Helm upgrade fails with error:
```bash
Error: UPGRADE FAILED: conflict occurred while applying object /kubex-resource-optimization-webhook
admissionregistration.k8s.io/v1, Kind=MutatingWebhookConfiguration: Apply failed with conflicts:
conflicts with "admissionsenforcer" using admissionregistration.k8s.io/v1:
- .webhooks[name="..."].namespaceSelector
```

**Cause:** Helm v4 uses server-side apply by default. External admission controllers (like `admissionsenforcer`, policy enforcers, or security tools) may modify the `MutatingWebhookConfiguration`, claiming field ownership. This creates conflicts when Helm tries to update the same fields.

**Solution:**
```bash
# Delete the webhook configuration before upgrading
kubectl delete mutatingwebhookconfiguration kubex-resource-optimization-webhook

# Then run your Helm upgrade
helm upgrade kubex-automation-controller densify/kubex-automation-controller \
  -n kubex -f kubex-automation-values.yaml
```
---

## Initial Deployment Issues

### Check Pod Status
```bash
# Verify all pods are running
kubectl get pods -n kubex

# Check pod details and events
kubectl describe pod <pod-name> -n kubex

# View pod logs
kubectl logs <pod-name> -n kubex -f
```

### Common Deployment Problems
- **ImagePullBackOff**: Check image names and registry access
- **CrashLoopBackOff**: Review pod logs for startup errors
- **Pending**: Check resource requests vs node capacity

## Controller Not Processing Pods

### Verify Configuration
```bash
# Check controller logs
kubectl logs -l app=kubex-controller -n kubex -f

# Verify scope configuration
kubectl get configmap kubex-automation-scope -n kubex -o yaml

# Check policy settings
kubectl get configmap kubex-automation-policy -n kubex -o yaml
```

### Common Controller Issues
- **No pods in scope**: Verify namespace and label selectors match target pods
- **Policy restrictions**: Check if automation is globally enabled
- **Resource quota limits**: Controller may skip optimizations if quota headroom is insufficient
- **HPA conflicts**: Controller skips pods with active HPAs on CPU/memory metrics
- **RBAC permission denied**: Verify ClusterRole and ClusterRoleBinding are properly configured
- **Cross-namespace access issues**: Controller requires cluster-wide permissions to validate resources

#### Pod Optimization Troubleshooting

1. **Verify pods are in scope:**
   ```bash
   # Check which pods match your scope configuration
   kubectl get pods -n <target-namespace> --show-labels
   
   # Compare with scope configuration
   kubectl get configmap kubex-automation-scope -n kubex -o yaml
   ```

2. **Check policy restrictions:**
   ```bash
   # Verify automation is enabled globally
   kubectl get configmap kubex-automation-policy -n kubex -o yaml | grep automationEnabled
   
   # Check policy enablement settings (shows upsize/downsize configuration)
   kubectl get configmap kubex-automation-policy -n kubex -o yaml
   # Look for the "enablement" section in the output to see upsize/downsize settings
   ```

3. **Look for safety blocks:**
   ```bash
   # Check for active HPAs on CPU/memory
   kubectl get hpa -A
   
   # Check PodDisruptionBudgets
   kubectl get pdb -A
   
   # Verify ResourceQuotas aren't blocking changes
   kubectl describe quota -n <target-namespace>
   
   # Check LimitRanges
   kubectl get limitrange -n <target-namespace> -o yaml
   ```

4. **Check for recent changes:**
   ```bash
   # Controller may skip recently modified pods
   kubectl get pods -n <target-namespace> -o custom-columns="NAME:.metadata.name,AGE:.metadata.creationTimestamp"
   ```

**Stale Recommendations:**
If seeing "recommendation too old" messages, the controller rejects recommendations older than `maxAnalysisAgeDays` (default: 5 days). Verify your Kubex instance is providing fresh recommendations.

## Webhook Not Mutating Pods

### Check Webhook Configuration
```bash
# Verify webhook is registered
kubectl get mutatingwebhookconfigurations

# Check webhook service and endpoints
kubectl get svc kubex-webhook-service -n kubex
kubectl get endpoints kubex-webhook-service -n kubex

# Test webhook connectivity
kubectl logs -l app=kubex-webhook -n kubex -f
```

### Common Webhook Issues
- **Certificate problems**: Check TLS certificate validity and CA bundle
- **Service unreachable**: Verify webhook service is running and accessible
- **Scope mismatch**: Ensure pod labels/namespaces match webhook selectors
- **Admission controller not receiving requests**: Check webhook failure policy

#### Certificate Issues with Custom Certificates

When not using cert-manager (default self-signed or BYOC), the secret **must** include the CA certificate:

**Check secret structure:**
```bash
kubectl get secret kubex-automation-tls -n kubex -o yaml
# Should show data keys: ca.crt, tls.crt, tls.key
```

**Common certificate problems:**
1. **Missing CA certificate**: The deployment expects `ca.crt` in the secret and mounts it at `/densify/tls/ca.crt`
2. **Wrong secret type**: Use `kubectl create secret generic` (not `tls`) when including the CA certificate
3. **CA bundle mismatch**: The MutatingWebhookConfiguration uses the CA certificate for `caBundle` validation
4. **DNS name mismatch**: Certificate must include required service DNS names (see [Certificates-BYOC.md](Certificates-BYOC.md))

**Fix certificate secret:**
```bash
# Delete the incorrect secret
kubectl delete secret kubex-automation-tls -n kubex

# Create with CA certificate included
kubectl create secret generic kubex-automation-tls \
  --from-file=tls.crt=your-cert.pem \
  --from-file=tls.key=your-key.pem \
  --from-file=ca.crt=your-ca.pem \
  -n kubex

# Restart pods to pick up the change
kubectl rollout restart deployment kubex-automation-controller -n kubex
kubectl rollout restart deployment kubex-webhook-server -n kubex
```

## Performance Issues

### Monitor Resource Usage
```bash
# Check controller resource consumption
kubectl top pod -n kubex

# View controller logs for activity
kubectl logs -l app=kubex-controller -n kubex -f
```

### Performance Indicators
- **Slow processing**: Look for "Single-threaded processing" behavior in large clusters
- **High memory usage**: May indicate recommendation cache buildup
- **API rate limiting**: Check for 429 errors in logs

## Valkey Cache Issues

### Check Valkey Status
```bash
# Verify Valkey pod is running
kubectl get pod -l app.kubernetes.io/name=valkey -n kubex

# Check Valkey connectivity
kubectl exec kubex-automation-controller-* -n kubex -- nc -z kubex-automation-controller-valkey 6379

# View Valkey logs
kubectl logs kubex-automation-controller-valkey-* -n kubex
```

### Common Valkey Problems
- **Connection failures**: Check password configuration and network connectivity
- **Storage issues**: Verify PVC is bound and has sufficient space
- **Authentication errors**: Check Valkey password special characters

#### Storage Troubleshooting

**Valkey pod failing to start with storage issues:**

1. **Check StorageClass availability:**
   ```bash
   kubectl get storageclass
   # Ensure your configured class exists and is available
   ```

2. **Verify PVC status:**
   ```bash
   kubectl get pvc -n kubex
   # Should show "Bound" status
   ```

3. **Check CSI drivers:**
   ```bash
   # Most managed services include required drivers by default
   kubectl get csidriver
   ```

4. **Update storage class configuration:**
   ```bash
   # In kubex-automation-values.yaml, set valkey.storage.className to an available StorageClass
   # Common examples: gp2 (EKS), azurefile (AKS), standard (GKE)
   ```

5. **Check cluster storage capacity:**
   ```bash
   kubectl describe nodes | grep -A5 -B5 "Allocatable\|Allocated resources"
   ```

## Configuration Debugging

### Validate YAML Syntax
```bash
# Test configuration changes
helm template densify/kubex-automation-controller -n kubex -f kubex-automation-values.yaml --debug

# Dry-run deployment
helm upgrade kubex-automation-controller densify/kubex-automation-controller -n kubex -f kubex-automation-values.yaml --dry-run
```

### Check Resource References
```bash
# Verify all ConfigMaps exist
kubectl get configmap -n kubex

# Check secret references
kubectl get secret -n kubex

# Validate RBAC permissions
kubectl auth can-i --list --as=system:serviceaccount:kubex:kubex-automation-controller-sa
```

#### Advanced Configuration Debugging

**Enable debug mode:**
1. Uncomment `debug: true` in the deployment section of `kubex-automation-values.yaml`
2. Run `helm upgrade kubex-automation-controller densify/kubex-automation-controller -n kubex -f kubex-automation-values.yaml`
3. View debug logs: `kubectl logs -l app=kubex-controller -n kubex -f`

**Validate configuration changes:**
```bash
# Check YAML syntax and template rendering
helm template densify/kubex-automation-controller -n kubex -f kubex-automation-values.yaml --debug

# Review all generated ConfigMaps
kubectl get configmap -n kubex -o yaml

# Test configuration without applying
helm upgrade kubex-automation-controller densify/kubex-automation-controller -n kubex -f kubex-automation-values.yaml --dry-run --debug
```

## Emergency Procedures

### Disable Automation Quickly

**Method 1: Configuration Update (Recommended)**
```bash
# Edit kubex-automation-values.yaml and set policy.automationEnabled to false
vim kubex-automation-values.yaml

# Apply the change via Helm upgrade
helm upgrade kubex-automation-controller densify/kubex-automation-controller -n kubex -f kubex-automation-values.yaml
```

**Method 2: Emergency Pod Scaling**
```bash
# Stop controller (prevents new evictions)
kubectl scale deployment kubex-automation-controller -n kubex --replicas=0

# Disable webhook (prevents new mutations)
kubectl delete mutatingwebhookconfigurations kubex-resource-optimization-webhook
```

### Reset Configuration
```bash
# Restart all components
kubectl rollout restart deployment -n kubex

# Clear Valkey cache
# - replace kubex-automation-controller-valkey-* with the valkey pod name
# - replace <valkey-password> with the valkey password, enclose in single quotes if contains special characters
kubectl exec kubex-automation-controller-valkey-* -n kubex -- valkey-cli --user kubexAutomation --pass '<valkey-password>' FLUSHALL
```

## Getting Help

### Collect Diagnostics
```bash
# Gather all logs from all components (including sidecar containers)
kubectl logs -l app=kubex-controller -n kubex --all-containers=true > kubex-controller-logs.txt
kubectl logs -l app=kubex-webhook -n kubex --all-containers=true > kubex-webhook-logs.txt
kubectl logs -l app.kubernetes.io/name=valkey -n kubex > kubex-valkey-logs.txt

# Export configurations and events
kubectl get configmap,secret,deployment -n kubex -o yaml > kubex-config.yaml
kubectl get events -n kubex --sort-by='.lastTimestamp' > kubex-events.txt
```

### Key Information to Provide
- Pod logs from all three components
- Current scope and policy configuration
- Target pod specifications and labels
- Any recent configuration changes
- Cluster version and size details