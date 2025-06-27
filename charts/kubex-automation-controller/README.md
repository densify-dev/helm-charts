# Kubex Automation Controller

This Helm chart enables the installation of Kubex Automation Controller on a Kubernetes cluster. It provides a way to automate resource optimization and management for containerized applications.

# Quick Links

- [Kubex Automation Controller](#kubex-automation-controller)
- [Quick Links](#quick-links)
- [Installation](#installation)
  - [Prerequisite: Configure Your Deployment](#prerequisite-configure-your-deployment)
  - [Quick Installation](#quick-installation)
    - [Option 1: Use cert-manager for self-signed cert management](#option-1-use-cert-manager-for-self-signed-cert-management)
    - [Option 2: Use your own certificate](#option-2-use-your-own-certificate)
    - [Examples](#examples)
  - [Manual Installation Steps (Advanced Users)](#manual-installation-steps-advanced-users)
- [Argo CD Integration](#argo-cd-integration)
  - [Add Resource Customizations to argocd-cm](#add-resource-customizations-to-argocd-cm)
- [Uninstalling](#uninstalling)
  - [Quick Uninstall](#quick-uninstall)
  - [Manual Uninstallation Steps (Advanced Users)](#manual-uninstallation-steps-advanced-users)
- [License](#license)


# Installation
## Prerequisite: Configure Your Deployment

Before installing, download and edit the configuration file:

1. Download the `values-edit.yaml` file
    ```bash
    wget https://github.com/densify-dev/helm-charts/raw/master/charts/kubex-automation-controller/values-edit.yaml
    ```

2. Edit the `values-edit.yaml` with your details. 

| Key                        | Default                               | Description                                                |
|----------------------------|---------------------------------------|------------------------------------------------------------|
| `certmanager.enabled`      | `false`                                | Set to true if using cert-manager for managing TLS certificates          |
| `config.DENSIFY_BASE_URL`  | `https://<customerName>.densify.com` | Densify API base URL                                       |
| `config.CLUSTER_NAME`      | `<clusterName>`                      | Kubernetes cluster name                |
| `secret.username`          | `<username>`                          | Densify automation user                       |
| `secret.epassword`          | `<epassword>`                          | Densify automation epassword                       |
| `policy.automationenabled` | `true`                                | Global Switch to enable/disable automation for the cluster |
| `policy.defaultpolicy`     | `cpu-reclaim`                         | Default policy to be used if one has not be explicitly selected                      |
| `policy.remoteenablement`  | `false`                               | Enable to add a second layer of dynamic control over automation scope from Kubex UI                |
| `webhook.caBundle`         | `null`         | Leave this as null if using cert-manager, otherwise replace with your base64-encoded CA certificate                     |
| `webhooks`                 | `List of webhook definitions`         | Configuration for mutating webhook(s)                      |
| `pv.accessMode`                 | `ReadWriteOnce`         | ReadWriteOnce or ReadWriteMany                      |
| `pv.storageClassName`                 | `default`         | Based on your storage classes                      |

3. If you do not want to use cert-manager for managing and automating your TLS certificate used by the Densify Admission Controller, you may use one of the alternative options:
 
    - [Generate Certificates Manually](./documentation/Certificates-Manual.md) 

    - [Bring Your Own Certificates (BYOC)](./documentation/Certificates-BYOC.md)

## Quick Installation

### Option 1: Use cert-manager for self-signed cert management
To use cert-manager for managing your self-signed certificate, run the following script. It checks whether cert-manager is already installed and installs it only if it isn't, before proceeding to deploy the Densify automation chart:
    
   ```bash
   wget https://github.com/densify-dev/helm-charts/raw/master/charts/kubex-automation-controller/deploy-kubex-automation-controller.sh
   chmod +x deploy-kubex-automation-controller.sh
   ./deploy-kubex-automation-controller.sh --certmanager
   ```
   
### Option 2: Use your own certificate
If you want to use your own certificate, run the following script:

   ```bash
   ./deploy-kubex-automation-controller.sh
   ```

### Examples
  ```bash
  # Deploy with cert-manager in the default namespace
  ./deploy-kubex-automation-controller.sh --certmanager

  # Deploy in a custom namespace without cert-manager
  ./deploy-kubex-automation-controller.sh --namespace custom-namespace

  # Uninstall both the controller and cert-manager
  ./deploy-kubex-automation-controller.sh --delete --certmanager
  ```

## Manual Installation Steps (Advanced Users)

If you prefer to run Helm manually or need more control over the setup, follow these steps:


Install cert-manager if you want to use it for managing your self-signed certicate. 

```bash
helm repo add jetstack https://charts.jetstack.io --force-update

helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.18.0 \
  --set crds.enabled=true
```


Add Densify Automation Helm Repo and Install:

```bash
helm repo add densify https://densify-dev.github.io/helm-charts
helm repo update
helm install --create-namespace -n densify -f values-edit.yaml kubex-automation-controller densify/kubex-automation-controller
```


# Argo CD Integration

If your Kubernetes cluster uses Argo CD, and you are enabling automated mutations via the Densify Mutating Admission Controller, you should configure Argo CD to ignore resource-related changes made by the controller.

This prevents:

- Applications from showing OutOfSync status unnecessarily.

- Infinite reconciliation loops when the Self-Heal flag is enabled.

## Add Resource Customizations to argocd-cm
Update the argocd-cm ConfigMap to ignore differences in container resource requests and limits for common workload types:

```bash
data:
  resource.customizations: |
    apps/Deployment:
      ignoreDifferences: |
        jqPathExpressions:
          - .spec.template.spec.containers[].resources.requests
          - .spec.template.spec.containers[].resources.limits
    apps/StatefulSet:
      ignoreDifferences: |
        jqPathExpressions:
          - .spec.template.spec.containers[].resources.requests
          - .spec.template.spec.containers[].resources.limits
    apps/DaemonSet:
      ignoreDifferences: |
        jqPathExpressions:
          - .spec.template.spec.containers[].resources.requests
          - .spec.template.spec.containers[].resources.limits
    argoproj.io/Rollout:
      ignoreDifferences: |
        jqPathExpressions:
          - .spec.template.spec.containers[].resources.requests
          - .spec.template.spec.containers[].resources.limits
```


# Uninstalling 

## Quick Uninstall
Uninstall Kubex Automation Controller Helm chart only:
```bash
./deploy-kubex-automation-controller.sh --delete
```

Uninstall Kubex Automation Controller Helm chart and cert-manager Helm chart:
```bash
./deploy-kubex-automation-controller.sh --delete --certmanager
```

## Manual Uninstallation Steps (Advanced Users)

Uninstall Kubex Automation Controller Helm Chart: 
```bash
    helm uninstall kubex-automation-controller -n densify

    kubectl delete namespace densify
```


Uninstall cert-manager Helm Chart: 
```bash

  helm uninstall cert-manager -n cert-manager

  kubectl delete crd \
  issuers.cert-manager.io \
  clusterissuers.cert-manager.io \
  certificates.cert-manager.io \
  certificaterequests.cert-manager.io \
  orders.acme.cert-manager.io \
  challenges.acme.cert-manager.io

  kubectl delete namespace cert-manager 
  
```


# License

Apache 2 Licensed. See [LICENSE](LICENSE) for full details.