# Getting Started with Kubex Automation Controller

This guide walks you through deploying Kubex Automation Controller in your Kubernetes cluster.

# Quick Links

- [Getting Started with Kubex Automation Controller](#getting-started-with-kubex-automation-controller)
- [Quick Links](#quick-links)
  - [Prerequisites](#prerequisites)
  - [Step 1: Download Configuration Template](#step-1-download-configuration-template)
  - [Step 2: Configure Connection Parameters](#step-2-configure-connection-parameters)
  - [Step 3: Configure Your Cluster](#step-3-configure-your-cluster)
  - [Step 4: Define Automation Scope](#step-4-define-automation-scope)
  - [Step 5: Set Up TLS Certificates](#step-5-set-up-tls-certificates)
    - [Option A: Use cert-manager (Recommended)](#option-a-use-cert-manager-recommended)
    - [Option B: Manual Certificate Management](#option-b-manual-certificate-management)
    - [Option C: Bring Your Own Certificates](#option-c-bring-your-own-certificates)
  - [Step 6: Deploy](#step-6-deploy)
    - [Quick Deploy (Recommended)](#quick-deploy-recommended)
    - [Manual Deploy](#manual-deploy)
  - [Step 7: Verify Installation](#step-7-verify-installation)
  - [Step 8: Create Your First Policy](#step-8-create-your-first-policy)
  - [Next Steps](#next-steps)
    - [Monitor Your First Optimizations](#monitor-your-first-optimizations)
    - [Expand Your Configuration](#expand-your-configuration)
    - [Need Help?](#need-help)

---

## Prerequisites

Before you begin, ensure you have:

- ✅ **Kubernetes cluster** with admin access
- ✅ **Helm 3.0+** installed
- ✅ **kubectl** configured for your cluster
- ✅ **Kubex UI access** for obtaining connection parameters
- ✅ **Storage configuration** for persistent volumes:
  - Available StorageClass in your cluster (e.g., `gp2` for EKS, `azurefile` for AKS, `standard` for GKE)
  - Required CSI drivers installed (most managed Kubernetes services include these by default)
  - At least 10Gi available storage capacity

---

## Step 1: Download Configuration Template and Installation Script

Download the configuration template and installation script:

```bash
curl -O https://github.com/densify-dev/helm-charts/raw/master/charts/kubex-automation-controller/kubex-automation-values.yaml
curl -O https://github.com/densify-dev/helm-charts/raw/master/charts/kubex-automation-controller/deploy-kubex-automation-controller.sh
chmod a+x ./deploy-kubex-automation-controller.sh
```

---

## Step 2: Configure Connection Parameters

1. **Log into Kubex UI** → Navigate to **Automation** tab
2. **Copy Connection Parameters** and paste into your `kubex-automation-values.yaml`:

```yaml
# ⚠️ Copy these EXACTLY from Kubex UI
densify:
  url:
    host: your-instance.densify.com

densifyCredentials:
  username: 'your-api-username'
  epassword: 'your-encrypted-password'
```

---

## Step 3: Configure Your Cluster

Set your cluster identification:

```yaml
cluster:
  name: my-production-cluster  # Choose a descriptive name

# Certificate management (recommended: use cert-manager)
certmanager:
  enabled: true  # Set to false if using your own certificates
```

---

## Step 4: Define Automation Scope

Configure which namespaces and workloads to automate:

```yaml
scope:
  - name: production-workloads
    policy: safe-optimization  # We'll create this policy in Step 8
    namespaces:
      operator: In
      values:
        - production
        - staging
    podLabels:
      - key: app
        operator: NotIn
        values:
          - database  # Exclude databases from automation
```

---

## Step 5: Set Up TLS Certificates

The webhook requires TLS certificates. Choose one option:

### Option A: Use cert-manager (Recommended)

```yaml
certmanager:
  enabled: true
```

### Option B: Manual Certificate Management

See our [Certificate Management Guide](./Certificates-Manual.md) for detailed instructions.

### Option C: Bring Your Own Certificates

See [BYOC Guide](./Certificates-BYOC.md) if you have existing certificates.

**Important**: When using custom certificates, your Kubernetes secret **must** include the CA certificate that signed your TLS certificate. The kubex-automation-controller requires this CA certificate for proper webhook operation.

---

## Step 6: Deploy

### Quick Deploy (Recommended)

```bash
# Deploy
## if using cert-manager:
./deploy-kubex-automation-controller.sh --certmanager
## otherwise (with your own certificates):
./deploy-kubex-automation-controller.sh
```

### Manual Deploy

```bash
# Add Helm repositories
helm repo add densify https://densify-dev.github.io/helm-charts
helm repo update

# Install cert-manager (if using)
## Install
helm repo add jetstack https://charts.jetstack.io
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.18.2 \
  --set crds.enabled=true
## Now wait for cert-manager deployments to be ready, for example using this
for deploy in cert-manager cert-manager-webhook cert-manager-cainjector; do
  echo "Waiting for deployment/$deploy rollout..."
  kubectl rollout status deployment/$deploy -n cert-manager --timeout=120s || {
    echo "Rollout failed for $deploy"
    exit 1
  }
done

# Deploy Kubex Automation Controller
## if using cert-manager:
helm upgrade --install kubex-automation-controller densify/kubex-automation-controller \
  --namespace kubex \
  --create-namespace \
  -f kubex-automation-values.yaml
  --set certmanager.enabled=true
## otherwise (with your own certificates):
helm upgrade --install kubex-automation-controller densify/kubex-automation-controller \
  --namespace kubex \
  --create-namespace \
  -f kubex-automation-values.yaml
  --set certmanager.enabled=false
```

---

## Step 7: Verify Installation

Check that all components are running:

```bash
# Check pod status
kubectl get pods -n kubex

# Expected output:
# NAME                                       READY   STATUS    RESTARTS   AGE
# kubex-automation-controller-xxx            2/2     Running   0          2m
# kubex-webhook-server-xxx                   2/2     Running   0          2m
# kubex-automation-controller-valkey-xxx     1/1     Running   0          2m

# Check webhook registration
kubectl get mutatingwebhookconfigurations | grep kubex

# View controller logs
kubectl logs -l app=kubex-controller -n kubex -f
```

---

## Step 8: Create Your First Policy

Add a safe automation policy to your `kubex-automation-values.yaml`:

```yaml
policy:
  automationEnabled: true
  defaultPolicy: safe-optimization
  
  policies:
    safe-optimization:
      # Only automate Deployments and StatefulSets
      allowedPodOwners: "Deployment,StatefulSet"
      
      enablement:
        cpu:
          request:
            downsize: false    # Start conservative - no downsizing
            upsize: true       # Allow CPU increases
            setFromUnspecified: false  # Don't set if not already set
          limit:
            downsize: false
            upsize: true
            setFromUnspecified: false
            
        memory:
          request:
            downsize: false    # Start conservative - no downsizing
            upsize: true       # Allow memory increases
            setFromUnspecified: false
          limit:
            downsize: false
            upsize: true
            setFromUnspecified: false
            
      # Safety settings
      safetyChecks:
        maxAnalysisAgeDays: 7  # Only use recent recommendations
      
      # Enable safe resizing methods
      inPlaceResize:
        enabled: true
      podEviction:
        enabled: true
```

Apply the updated configuration:

```bash
helm upgrade kubex-automation-controller densify/kubex-automation-controller \
  -n kubex -f kubex-automation-values.yaml
```

---

## Next Steps

🎉 **Congratulations!** Kubex Automation Controller is now running with a conservative policy.

### Monitor Your First Optimizations

```bash
# Watch controller activity
kubectl logs -l app=kubex-controller -n kubex -f

# Check for optimization events
kubectl get events -n kubex --sort-by='.lastTimestamp'
```

### Expand Your Configuration

Once comfortable with the basic setup:

1. **[Policy Configuration](./Policy-Configuration.md)** - Create more sophisticated automation rules
2. **[Advanced Configuration](./Advanced-Configuration.md)** - Node scheduling, performance tuning
3. **[Configuration Updates](./Configuration-Updates.md)** - Learn safe update procedures

### Need Help?

- **Configuration Questions**: See [Configuration Reference](./Configuration-Reference.md)
- **Issues**: Check [Troubleshooting Guide](./Troubleshooting.md)
- **Large Clusters**: Review [Pod Scan Configuration](./Pod-Scan-Configuration.md)

---

**Ready to optimize?** Your automation controller is now actively monitoring your cluster and will begin applying safe optimizations according to your policy!