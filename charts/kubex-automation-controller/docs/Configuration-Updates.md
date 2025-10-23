# Configuration Update Procedures

This guide explains the critical differences between various types of configuration changes and how to apply them safely.

# Quick Links

- [Configuration Update Procedures](#configuration-update-procedures)
- [Quick Links](#quick-links)
- [⚠️ Critical Information](#️-critical-information)
- [Policy Updates vs. Scope Changes](#policy-updates-vs-scope-changes)
  - [✅ Policy Updates (Safe to edit ConfigMap directly)](#-policy-updates-safe-to-edit-configmap-directly)
  - [⚠️ Scope Changes \& New Policies (Requires Helm upgrade)](#️-scope-changes--new-policies-requires-helm-upgrade)
- [Why Scope Changes Are Different](#why-scope-changes-are-different)
- [Correct Update Procedures](#correct-update-procedures)
  - [For Policy Setting Changes](#for-policy-setting-changes)
  - [For Scope Changes or New Policies](#for-scope-changes-or-new-policies)
- [What Gets Updated During Helm Upgrade](#what-gets-updated-during-helm-upgrade)
- [Summary Guidelines](#summary-guidelines)

---

## ⚠️ Critical Information

**CRITICAL:** Different types of configuration changes require different update procedures. Using the wrong procedure can create dangerous inconsistencies between components.

## Policy Updates vs. Scope Changes

### ✅ Policy Updates (Safe to edit ConfigMap directly)
If you need to **modify existing policy settings** (e.g., change CPU/memory thresholds, enable/disable features), you can update the ConfigMap directly:

```bash
# Edit existing policy settings
kubectl edit configmap kubex-automation-policy -n kubex
```

The automation controller will pick up these changes within ~60 seconds without requiring pod restarts.

### ⚠️ Scope Changes & New Policies (Requires Helm upgrade)
The following changes **MUST** be done via Helm upgrade:
- Adding or removing scope definitions
- Adding new policies to the `policy.policies` section
- Changing namespace or pod label selectors
- Modifying which policy a scope uses

## Why Scope Changes Are Different

The scope configuration is used in **two places simultaneously**:

1. **MutatingWebhookConfiguration** - Tells Kubernetes which pods to intercept and send to the webhook server
2. **ConfigMap** (`kubex-automation-scope`) - Tells the automation controller which pods to process for optimization

If you edit the scope ConfigMap directly:
- ✅ **Automation Controller**: Uses the new scope from the updated ConfigMap
- ❌ **Webhook Server**: Still uses the old scope from the MutatingWebhookConfiguration  
- 🚨 **Result**: Components become out of sync, leading to unpredictable behavior

## Correct Update Procedures

### For Policy Setting Changes
```bash
# Option 1: Direct ConfigMap edit (immediate effect)
kubectl edit configmap kubex-automation-policy -n kubex

# Option 2: Helm upgrade (consistent with other changes)
vim kubex-automation-values.yaml
helm upgrade <release-name> densify/kubex-automation-controller -f kubex-automation-values.yaml
```

### For Scope Changes or New Policies
```bash
# 1. Edit your configuration
vim kubex-automation-values.yaml

# 2. Apply changes via Helm upgrade
helm upgrade <release-name> densify/kubex-automation-controller -f kubex-automation-values.yaml

# 3. Verify both components are updated
kubectl get mutatingwebhookconfiguration kubex-resource-optimization-webhook -o yaml
kubectl get configmap kubex-automation-scope -n kubex -o yaml
```

## What Gets Updated During Helm Upgrade

- ✅ MutatingWebhookConfiguration (webhook server scope)  
- ✅ ConfigMaps (automation controller scope and policies)
- ✅ Secrets (if credentials changed)
- ✅ All other Kubernetes resources as needed

## Summary Guidelines

| Change Type | ConfigMap Edit | Helm Upgrade | Notes |
|-------------|----------------|--------------|-------|
| **Policy settings** (automation enablement settings) | ✅ Safe | ✅ Also works | ConfigMap changes take effect in ~60 seconds |
| **Scope definitions** (namespaces, pod labels) | ❌ Dangerous | ✅ Required | Must keep webhook and controller in sync |
| **New policies** | ❌ Incomplete | ✅ Required | Policy must exist in both places |
| **Policy assignments** (which policy a scope uses) | ❌ Dangerous | ✅ Required | Must update both webhook and ConfigMap |