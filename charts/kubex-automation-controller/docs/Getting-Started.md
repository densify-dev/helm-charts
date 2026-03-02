
# Getting Started with Kubex Automation Controller

This guide walks you through deploying **Kubex Automation Controller** in your Kubernetes cluster using the default, auto-generated self-signed certificates. Advanced certificate options are covered [here](]11._Advanced:_Custom_Certificate_Options).

# Quick Links

1.  [Prerequisites](#prerequisites)
2.  [Download Configuration Files](#step-1-download-configuration-files)
3.  Configure Connection Parameters\
4.  Configure Valkey\
5.  Configure Cluster Identification\
6.  Define Automation Scope\
7.  Configure Automation Policy\
8.  Container Resource Sizing Guidance\
9.  Install Kubex Automation Controller\
10. Verify Installation\
11. Advanced: Custom Certificate Options\
12. Next Steps

- [Getting Started with Kubex Automation Controller](#getting-started-with-kubex-automation-controller)
- [Quick Links](#quick-links)
  - [Prerequisites](#prerequisites)
  - [Step 1: Download Configuration Files](#step-1-download-configuration-files)
  - [Step 2: Configure Connection Parameters](#step-2-configure-connection-parameters)
  - [Step 3: Container Resource Sizing Guidance](#step-3-container-resource-sizing-guidance)
    - [kubex-automation-controller](#kubex-automation-controller)
    - [kubex-automation-gw](#kubex-automation-gw)
    - [kubex-webhook-server](#kubex-webhook-server)
    - [kubex-webhook-gw](#kubex-webhook-gw)
    - [valkey-server](#valkey-server)
    - [valkey-exporter](#valkey-exporter)
  - [Step 4: Configure Valkey Parameters](#step-4-configure-valkey-parameters)
  - [Step 5: Configure Your Cluster](#step-5-configure-your-cluster)
  - [Step 6: Define Automation Scope](#step-6-define-automation-scope)
  - [Step 6: Configure Automation Policy](#step-6-configure-automation-policy)
  - [Step 7: Install Kubex Automation Controller](#step-7-install-kubex-automation-controller)
    - [Standard Kubernetes Installation](#standard-kubernetes-installation)
    - [OpenShift Installation](#openshift-installation)
  - [Step 8: Verify Installation](#step-8-verify-installation)
  - [Next Steps](#next-steps)
    - [Monitor Your First Optimizations](#monitor-your-first-optimizations)
    - [Advanced: Custom Certificate Options](#advanced-custom-certificate-options)
    - [Expand Your Scope](#expand-your-scope)
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

## Step 1: Download Configuration Files

Download the configuration template and installation script:

```bash
curl -LO https://github.com/densify-dev/helm-charts/raw/master/charts/kubex-automation-controller/kubex-automation-values.yaml
curl -LO https://github.com/densify-dev/helm-charts/raw/master/charts/kubex-automation-controller/deploy-kubex-automation-controller.sh
chmod a+x ./deploy-kubex-automation-controller.sh
```
If running on OpenShift, also download: 
```bash
curl -LO https://github.com/densify-dev/helm-charts/raw/master/charts/kubex-automation-controller/values-openshift.yaml
```

Open `kubex-automation-values.yaml` with your preferred editor. You'll be pasting values into it in steps 2-6 below. When done, save your changes.

The instructions in this document assume that you leave the value of `createSecrets` to be `true`, and let the helm chart create the required secrets. If you want to provide external secrets, managed by some secret management tool, please follow [these instructions](./Configuration-Reference.md#secret-management-configuration).

---

## Step 2: Configure Connection Parameters

1. **Log into Kubex UI** → Navigate to **Automation** tab
2. **Copy Connection Parameters** and paste into your `kubex-automation-values.yaml`:

```yaml
# ⚠️ Copy these EXACTLY from Kubex UI
densify:
  url:
    host: your-instance.kubex.ai

densifyCredentials:
  username: 'your-api-username'
  epassword: 'your-encrypted-password'
```

---

## Step 3: Container Resource Sizing Guidance

Container resource requests and limits should be adjusted based on the size of your cluster and the number of managed containers. Use the following recommendations as a starting point:

### kubex-automation-controller

| Resource         | Small (0–1K) | Medium (1K–10K) | Large (10K+) |
|------------------|--------------|-----------------|--------------|
| CPU Request      | 25m          | 200m            | 400m         |
| CPU Limit        | -            | -               | -            |
| Memory Request   | 500Mi        | 2Gi             | 4Gi          |
| Memory Limit     | 1Gi          | 4Gi             | 6Gi          |

### kubex-automation-gw

| Resource         | Small (0–1K) | Medium (1K–10K) | Large (10K+) |
|------------------|--------------|-----------------|--------------|
| CPU Request      | 15m          | 15m             | 25m          |
| CPU Limit        | -            | -               | -            |
| Memory Request   | 40Mi         | 60Mi            | 90Mi         |
| Memory Limit     | 250Mi        | 350Mi           | 500Mi        |

### kubex-webhook-server

| Resource         | Small (0–1K) | Medium (1K–10K) | Large (10K+) |
|------------------|--------------|-----------------|--------------|
| CPU Request      | 15m          | 15m             | 15m          |
| CPU Limit        | -            | -               | -            |
| Memory Request   | 30Mi         | 55Mi            | 80Mi         |
| Memory Limit     | 200Mi        | 350Mi           | 500Mi        |

### kubex-webhook-gw

| Resource         | Small (0–1K) | Medium (1K–10K) | Large (10K+) |
|------------------|--------------|-----------------|--------------|
| CPU Request      | 10m          | 15m             | 15m          |
| CPU Limit        | -            | -               | -            |
| Memory Request   | 20Mi         | 30Mi            | 40Mi         |
| Memory Limit     | 150Mi        | 200Mi           | 250Mi        |

### valkey-server

| Resource         | Small (0–1K) | Medium (1K–10K) | Large (10K+) |
|------------------|--------------|-----------------|--------------|
| CPU Request      | 10m          | 20m             | 30m          |
| CPU Limit        | -            | -               | -            |
| Memory Request   | 40Mi         | 52Mi            | 64Mi         |
| Memory Limit     | 200Mi        | 250Mi           | 300Mi        |

### valkey-exporter

| Resource         | Small (0–1K) | Medium (1K–10K) | Large (10K+) |
|------------------|--------------|-----------------|--------------|
| CPU Request      | 10m          | 10m             | 10m          |
| CPU Limit        | -            | -               | -            |
| Memory Request   | 20Mi         | 26Mi            | 32Mi         |
| Memory Limit     | 100Mi        | 110Mi           | 120Mi        |


> **Sizing Notes:**
> - "Small" = up to 1,000 managed containers
> - "Medium" = 1,000–10,000 managed containers
> - "Large" = more than 10,000 managed containers
> - Adjust values as needed for your environment and workload patterns.


## Step 4: Configure Valkey Parameters

Set your valkey parameters as follows:

- The password is **mandatory**, must be quoted if it includes special characters and **cannot** include spaces
- Optional: generate the password using the instructions [in the configuration reference](./Configuration-Reference.md#generating-a-valkey-password)
- Set the storage class name if your cluster requires explicit storage class
- Set the node selector, affinity, tolerations and/or topology spread constraints if these are required

```yaml
valkey:
  credentials:
    password: '<password>' # quote if includes special characters, cannot include SPACES
  # storage:
  #   className: <storageClassName> # Optional. Define if your environment requires it. 
  # nodeSelector: {} # Optional. Define if your environment requires it.
  # affinity: {} # Optional. Define if your environment requires it.
  # tolerations: [] # Optional. Define if your environment requires it.
  # topologySpreadConstraints: [] # Optional. Define if your environment requires it.
```

---

## Step 5: Configure Your Cluster

Set your cluster identification:

```yaml
cluster:
  name: my-production-cluster  # Choose a descriptive name
```

---

## Step 6: Define Automation Scope

Configure which namespaces and workloads to automate:

```yaml
scope:
  - name: production-workloads  # Unique identifier
    policy: base-optimization   # Uses the default policy
    namespaces:
      operator: In              # 'In' to include, 'NotIn' to exclude
      values:
        - production
        - staging
    podLabels:
      - key: app
        operator: NotIn         # 'In' to include, 'NotIn' to exclude
        values:
          - database            # Exclude databases from automation
```

**Key Rules & Recommendations:**

**Scope Inclusion Guidance:**
- Use `operator: In` to include matching items, `operator: NotIn` to exclude them
- Exclude platform and operator-managed namespaces (operators reconcile resources and may override automation changes)
- Exclude all `openshift-*` namespaces (if running on OpenShift - contain critical OpenShift platform components)
- Exclude the `kubex` namespace (where kubex-automation-controller is installed)
- These namespaces are auto-excluded by default: `kube-node-lease`, `kube-public`, `kube-system` 

**Other Guidance:**
- Required fields: `name`, `policy`, `namespaces`
- Optional field: `podLabels` (adds additional filtering on top of namespace selection)

**Multiple Scopes:** Define separate scopes for different environments by repeating the block with different names, policies, and filters. See [Configuration Reference](./Configuration-Reference.md#scope-definition-manual-input) for examples and field details

---

## Step 6: Configure Automation Policy

**No configuration needed!** The chart includes a safe `base-optimization` policy by default:

- ✅ Allows CPU and memory request optimization (both upsize and downsize)
- ✅ Allows CPU and memory limit increases
- ⚠️ Prevents memory limit decreases (for stability)
- 🔒 Only optimizes Deployments, StatefulSets, CronJobs, Jobs, Rollouts, ReplicaSets, and AnalysisRuns
- 📅 Uses recommendations up to 5 days old

This policy is already referenced in your scope configuration from Step 5.

**Want to customize?** See [Policy Configuration](./Policy-Configuration.md) for advanced options like:
- Creating more conservative policies (upsize-only)
- Enabling aggressive optimization (DaemonSets, all limits)
- Adjusting safety thresholds

---


## Step 7: Install Kubex Automation Controller

### Standard Kubernetes Installation

By default, the chart will auto-generate a self-signed certificate for the webhook. No extra configuration is needed for certificates.

Install using the deploy script (recommended):

```bash
./deploy-kubex-automation-controller.sh
```

Or install using Helm directly:

```bash
helm upgrade --install kubex-automation-controller kubex/kubex-automation-controller \
  --namespace kubex \
  --create-namespace \
  -f kubex-automation-values.yaml
```

### OpenShift Installation

For OpenShift, use the deploy script with the `--openshift` flag (recommended):

```bash
./deploy-kubex-automation-controller.sh --openshift
```

Or install using Helm directly:

```bash
helm upgrade --install kubex-automation-controller kubex/kubex-automation-controller \
  -n kubex --create-namespace \
  -f kubex-automation-values.yaml \
  -f values-openshift.yaml
```

The `values-openshift.yaml` file will enable OpenShift-specific settings and service account overrides.

---

done

## Step 8: Verify Installation

Check that all components are running:

```bash
# Check pod status
kubectl get pods -n kubex

# Expected output:
# NAME                                       READY   STATUS    RESTARTS   AGE
# kubex-automation-controller-xxx            2/2     Running   0          2m
# kubex-automation-controller-valkey-xxx     2/2     Running   0          2m
# kubex-webhook-server-xxx                   2/2     Running   0          2m


# Check webhook registration
kubectl get mutatingwebhookconfigurations | grep kubex

# View controller logs
kubectl logs -l app=kubex-controller -n kubex -f
```

---

## Next Steps

🎉 **Congratulations!** Kubex Automation Controller is now running with a conservative policy.

### Monitor Your First Optimizations

You can observe optimization activity directly in your cluster or view automation actions through the Kubex UI.

```bash
# Watch Controller Activity for Pod Evictions & In-Place Resizing
kubectl logs -l app=kubex-controller -n kubex -f

# Watch Webhook Server Activity for Resizing Upon Pod Creation
kubectl logs -l app=kubex-webhook -n kubex -f

# Check for Optimization Events
kubectl get events -n <namespace where you are automating> --sort-by='.lastTimestamp'
```

### Advanced: Custom Certificate Options

If you need to use cert-manager or bring your own certificates (BYOC), see the [Advanced Configuration](./Advanced-Configuration.md) and [Certificates-BYOC.md](./Certificates-BYOC.md) guides for details. These options are not required for most users.


### Expand Your Scope

Once comfortable with the basic setup:

1. **[Policy Configuration](./Policy-Configuration.md)** - Create more sophisticated automation rules
2. **[Advanced Configuration](./Advanced-Configuration.md)** - Node scheduling, performance tuning
3. **Reapply via deploy script or `helm upgrade`** - Edit `kubex-automation-values.yaml` and rerun either the deploy script or the `helm upgrade` command from [Step 8](#step-8-deploy) after every change:

```bash
helm upgrade --install kubex-automation-controller kubex/kubex-automation-controller \
  -n kubex --create-namespace \
  -f kubex-automation-values.yaml
```
> **For OpenShift, use:**
```bash
helm upgrade --install kubex-automation-controller kubex/kubex-automation-controller \
  -n kubex --create-namespace \
  -f kubex-automation-values.yaml \
  -f values-openshift.yaml
```

### Need Help?

- **Configuration Questions**: See [Configuration Reference](./Configuration-Reference.md)
- **Issues**: Check [Troubleshooting Guide](./Troubleshooting.md)
- **Large Clusters**: Review [Pod Scan Configuration](./Pod-Scan-Configuration.md)

---

**Ready to optimize?** Your automation controller is now actively monitoring your cluster and will begin applying safe optimizations according to your policy!


---
