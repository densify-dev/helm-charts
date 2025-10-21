# Policy Configuration Guide

This guide describes how to configure policies for the Kubex Automation Controller directly in your `kubex-automation-values.yaml` file.

**Quick Navigation:** [Configuration Structure](#configuration-structure) | [Field Reference](#policy-field-reference) | [Adding Policies](#adding-multiple-policies) | [Examples](#common-policy-examples)

## ⚠️ Important: Policy Naming Requirements

**Policy names MUST follow RFC 1123 subdomain rules:**

- ✅ **Use lowercase letters, numbers, hyphens, and dots only**
- ✅ **Start and end with alphanumeric characters**
- ❌ **No uppercase letters, underscores, or special characters**

### Examples:
```yaml
# ✅ Valid policy names
base-optimization          # lowercase with hyphens
dev-env                    # short and simple
production.cpu.aggressive  # dots are allowed
stage2-memory             # numbers are allowed

# ❌ Invalid policy names (will cause deployment errors)
baseOptimization          # camelCase not allowed
dev_environment           # underscores not allowed  
PRODUCTION               # uppercase not allowed
aggressive-cpu!          # special characters not allowed
```

**Why this matters**: Policy names become part of Kubernetes webhook URLs (`/mutate/{policy-name}`), and Kubernetes enforces strict RFC 1123 validation on webhook paths.

---

# Configuration Structure

Policy configuration is defined in your `kubex-automation-values.yaml` file under the `policy` section with three main parts: **Global Settings**, **Automation Scope Control**, and **Policy Definitions**.

```yaml
policy:
  # ================================================================
  # GLOBAL SETTINGS
  # ================================================================
  automationEnabled: true                 # Global switch to enable/disable automation for the cluster
  defaultPolicy: base-optimization        # Default policy used when scope.policy is not specified
  
  # ================================================================
  # AUTOMATION SCOPE CONTROL
  # Determines where automation inclusion/exclusion rules are defined
  # ================================================================
  remoteEnablement: false
    # false: Automation scope controlled ONLY by this Helm configuration
    #        - Recommended for strict GitOps workflows and production environments
    # true:  Automation scope controlled by BOTH Helm configuration AND Densify UI
    #        - Provides flexibility for ad-hoc automation control without Helm updates
    #        - Useful for development environments and testing scenarios
  
  # ================================================================
  # POLICY DEFINITIONS
  # ================================================================ 
  policies: 
    base-optimization:
      allowedPodOwners: "Deployment,StatefulSet,CronJob,Rollout,Job,ReplicaSet,AnalysisRun"
      enablement:
        cpu:
          request:
            downsize: true
            upsize: true
            setFromUnspecified: false
          limit:
            downsize: true
            upsize: true
            setFromUnspecified: false
            unsetFromSpecified: false     # (Future release)
        memory:
          request:
            downsize: true
            upsize: true
            setFromUnspecified: false
          limit:
            downsize: false
            upsize: true
            setFromUnspecified: false
      inPlaceResize:                      # (Future release)
        enabled: false
      inPlaceResizeContainerRestart:      # (Future release)
        enabled: false
      podEviction:
        enabled: true
      safetyChecks:
        maxAnalysisAgeDays: 5             # Number of days before optimization is considered stale
```

---

# Policy Field Reference

## Global Settings

| Field                  | Description                                                                                     | Default Value |
| ---------------------- | ----------------------------------------------------------------------------------------------- | ------------- |
| `automationEnabled`    | Global switch to enable or disable automation for the entire cluster                           | `true`        |
| `defaultPolicy`        | Policy name to use when a scope doesn't specify a policy                                       | `base-optimization` |
| `remoteEnablement`     | Controls whether automation scope can be modified via Densify UI in addition to Helm configuration | `false`   |

### Remote Enablement Options:
- **`false`** (Recommended for production):
  - Automation scope controlled **ONLY** by Helm configuration
  - Densify UI cannot override automation decisions
  - Best for strict GitOps workflows and production environments
  
- **`true`** (Useful for development):
  - Automation scope controlled by **BOTH** Helm configuration AND Densify UI
  - Allows ad-hoc automation control without Helm updates
  - Provides flexibility for development and testing scenarios

## Policy Definitions

### Allowed Pod Owners

| Field                  | Description                                                                                     | Default Value |
| ---------------------- | ----------------------------------------------------------------------------------------------- | ------------- |
| `allowedPodOwners`     | Comma-separated list of Kubernetes resource types that are eligible for automation             | `"Deployment,StatefulSet,CronJob,Rollout,Job,ReplicaSet,AnalysisRun"` |

### Enablement Section

Controls which types of changes are allowed for CPU and memory resources.

| Path                                    | Meaning                                | Default Value |
| --------------------------------------- | -------------------------------------- | ------------- |
| `enablement.cpu.request.downsize`      | Permit reductions to CPU requests      | `true`        |
| `enablement.cpu.request.upsize`        | Permit increases to CPU requests       | `true`        |
| `enablement.cpu.request.setFromUnspecified`    | Set CPU request if previously unset    | `false`       |
| `enablement.cpu.limit.downsize`        | Permit reductions to CPU limits        | `true`        |
| `enablement.cpu.limit.upsize`          | Permit increases to CPU limits         | `true`        |
| `enablement.cpu.limit.setFromUnspecified`      | Set CPU limit if previously unset      | `false`       |
| `enablement.cpu.limit.unsetFromSpecified`      | Remove CPU limit if already set        | `false`       |  
| `enablement.memory.request.downsize`   | Permit reductions to Memory requests   | `true`        |
| `enablement.memory.request.upsize`     | Permit increases to Memory requests    | `true`        |
| `enablement.memory.request.setFromUnspecified` | Set Memory request if previously unset | `false`       |
| `enablement.memory.limit.downsize`     | Permit reductions to Memory limits     | `false`       |
| `enablement.memory.limit.upsize`       | Permit increases to Memory limits      | `true`        |
| `enablement.memory.limit.setFromUnspecified`   | Set Memory limit if previously unset   | `false`       |

### Other Policy Controls

| Section                         | Key                  | Description                                                                          | Default Value |
| ------------------------------- | -------------------- | ------------------------------------------------------------------------------------ | ------------- |
| `inPlaceResize`                 | `enabled`            | Allow in-place resizing without pod restart. (Future Release)                                        | `false`        |
| `inPlaceResizeContainerRestart` | `enabled`            | Allow restarting containers after in-place resize only if the pod's restartPolicy allows it. (FUture Release) | `false`        |
| `podEviction`                   | `enabled`            | Allow eviction-based resizing.                                                      | `true`        |
| `safetyChecks`                  | `maxAnalysisAgeDays` | Max age (in days) of recommendations used for automation. Older analysis is ignored. | `5`           |

---

# Adding Multiple Policies

To define multiple policies with different automation behaviors:

## Step 1: Copy the Policy Block
Copy the entire policy block (everything under `base-optimization:`) and paste it with a new name:

```yaml
policy:
  policies:
    base-optimization:
      # ... existing policy ...
    
    dev-environment:  # ← New policy name
      allowedPodOwners: "Deployment,StatefulSet" 
      enablement:
        cpu:
          request: { downsize: false, upsize: true, setFromUnspecified: true }
          limit: { downsize: false, upsize: true, setFromUnspecified: false }
        memory:
          request: { downsize: false, upsize: true, setFromUnspecified: true }
          limit: { downsize: false, upsize: true, setFromUnspecified: true }
      podEviction: { enabled: true }
      safetyChecks: { maxAnalysisAgeDays: 3 }
```

## Step 2: Reference the Policy in Scope
Update your scope configuration to use the new policy:

```yaml
scope:
  - name: production-scope
    policy: base-optimization
    namespaces: { operator: In, values: ["production", "staging"] }
    podLabels:
      - key: env
        operator: In
        values: ["production", "staging"]
        
  - name: development-scope
    policy: dev-environment
    namespaces: { operator: In, values: ["development", "testing"] }
    podLabels:
      - key: env
        operator: In
        values: ["development", "testing"]
```

> **📖 For detailed scope configuration guidance**, see the [Configuration Reference - Scope Definition](Configuration-Reference.md#scope-definition-manual-input) section.

---

# Common Policy Examples

## Base Optimization (Default Release Policy)
This is the default policy included in the release - balanced for production use with conservative settings for limits and requests:

```yaml
policy:
  automationEnabled: true
  defaultPolicy: base-optimization
  remoteEnablement: false
  
  policies:
    base-optimization:
      allowedPodOwners: "Deployment,StatefulSet,CronJob,Rollout,Job,ReplicaSet,AnalysisRun"
      enablement:
        cpu:
          request:
            downsize: true
            upsize: true
            setFromUnspecified: false      # Don't set CPU requests if not already specified
          limit:
            downsize: true
            upsize: true
            setFromUnspecified: false      # Don't set CPU limits if not already specified
            unsetFromSpecified: false      # (Future release)
        memory:
          request:
            downsize: true
            upsize: true
            setFromUnspecified: false      # Don't set memory requests if not already specified
          limit:
            downsize: false                # Conservative: don't reduce memory limits
            upsize: true
            setFromUnspecified: false      # Don't set memory limits if not already specified
      inPlaceResize:                       # (Future release)
        enabled: false
      inPlaceResizeContainerRestart:       # (Future release)
        enabled: false
      podEviction:
        enabled: true
      safetyChecks:
        maxAnalysisAgeDays: 5
```

## Full Optimization (All Settings Enabled)
This policy enables all automation features - suitable for development or testing environments where maximum optimization is desired:

```yaml
policy:
  automationEnabled: true
  defaultPolicy: full-optimization
  remoteEnablement: true                 # Allow UI overrides for flexibility
  
  policies:
    full-optimization:
      allowedPodOwners: "Deployment,StatefulSet,CronJob,Rollout,Job,ReplicaSet,AnalysisRun,DaemonSet"
      enablement:
        cpu:
          request:
            downsize: true
            upsize: true
            setFromUnspecified: true       # Set CPU requests if missing
          limit:
            downsize: true
            upsize: true
            setFromUnspecified: true       # Set CPU limits if missing
            unsetFromSpecified: false      # (Future release)
        memory:
          request:
            downsize: true
            upsize: true
            setFromUnspecified: true       # Set memory requests if missing
          limit:
            downsize: true                 # Allow memory limit reductions
            upsize: true
            setFromUnspecified: true       # Set memory limits if missing
      inPlaceResize:                       # (Future release)
        enabled: false
      inPlaceResizeContainerRestart:       # (Future release)
        enabled: false
      podEviction:
        enabled: true
      safetyChecks:
        maxAnalysisAgeDays: 7              # Use older analysis if needed
```
      podEviction:
        enabled: true
      safetyChecks:
        maxAnalysisAgeDays: 5
```

## Full Optimization (All Settings Enabled)
This policy enables all automation features - suitable for development or testing environments where maximum optimization is desired:

```yaml
policy:
  automationEnabled: true
  defaultPolicy: full-optimization
  remoteEnablement: true                 # Allow UI overrides for flexibility
  
  policies:
    full-optimization:
      allowedPodOwners: "Deployment,StatefulSet,CronJob,Rollout,Job,ReplicaSet,AnalysisRun,DaemonSet"
      enablement:
        cpu:
          request:
            downsize: true
            upsize: true
            setFromUnspecified: true       # Set CPU requests if missing
          limit:
            downsize: true
            upsize: true
            setFromUnspecified: true       # Set CPU limits if missing
            unsetFromSpecified: false      # (Future release)
        memory:
          request:
            downsize: true
            upsize: true
            setFromUnspecified: true       # Set memory requests if missing
          limit:
            downsize: true                 # Allow memory limit reductions
            upsize: true
            setFromUnspecified: true       # Set memory limits if missing
      inPlaceResize:                       # (Future release)
        enabled: false
      inPlaceResizeContainerRestart:       # (Future release)
        enabled: false
      podEviction:
        enabled: true
      safetyChecks:
        maxAnalysisAgeDays: 7              # Use older analysis if needed
```

## ⚠️ Important: Policy Naming Requirements

**Policy names MUST follow RFC 1123 subdomain rules:**

- ✅ **Use lowercase letters, numbers, hyphens, and dots only**
- ✅ **Start and end with alphanumeric characters**
- ❌ **No uppercase letters, underscores, or special characters**

### Examples:
```yaml
# ✅ Valid policy names
base-optimization          # lowercase with hyphens
dev-env                    # short and simple
production.cpu.aggressive  # dots are allowed
stage2-memory             # numbers are allowed

# ❌ Invalid policy names (will cause deployment errors)
baseOptimization          # camelCase not allowed
dev_environment           # underscores not allowed  
PRODUCTION               # uppercase not allowed
aggressive-cpu!          # special characters not allowed
```

**Why this matters**: Policy names become part of Kubernetes webhook URLs (`/mutate/{policy-name}`), and Kubernetes enforces strict RFC 1123 validation on webhook paths.
