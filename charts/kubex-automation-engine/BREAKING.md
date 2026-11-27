# Breaking Changes

## Next release: explicit GPU request/limit pairs and permissions

GPU requests and limits are independently opt-in on `AutomationStrategy` and `ClusterAutomationStrategy`. Both default to disabled. Enabling request changes no longer authorizes limit changes. Update policy targets and strategy permissions together before relying on GPU automation after upgrading.

### Migrate static targets

For both `StaticPolicy` and `ClusterStaticPolicy`, each container entry with `requests.gpu` must also specify `limits.gpu` in that same entry, including wildcard `"*"` entries. A limit in another entry or policy does not satisfy admission, even with multi-policy composition enabled. Add an explicit limit to existing request-only policies before upgrading.

For every container, the effective selected recommendation must include both `requests.gpu` and `limits.gpu`. Neither omitted member falls back to the other member, the live Pod, or the workload template. Limit-only entries remain accepted, but execution requires a complete selected pair. Legacy incomplete selections block the entire resize plan immediately after upgrading, including CPU and memory actions, even when GPU actions are disabled on the strategy. Correct these selections before upgrading. Admission remains backend-neutral; the controller validates selected pairs before building actions and checks backend constraints after bounds.

Before, a request-only `StaticPolicy` target could rely on implicit pairing:

```yaml
spec:
  resources:
    containers:
      app:
        requests:
          gpu: "0.5"
```

After, explicitly select both members. This `StaticPolicy` fragment is suitable for KAI HAMi-core:

```yaml
spec:
  resources:
    containers:
      app:
        requests:
          gpu: "0.5"
        limits:
          gpu: "0.5"
```

The same migration applies to `ClusterStaticPolicy`.

- Native NVIDIA requires equal logical targets before rounding up to whole GPUs. Unequal targets are rejected even if they would round to the same integer.
- KAI HAMi-core requires equal targets.
- KAI NvFractions allows separate targets satisfying `0 < request <= limit < 1`, for example request `"0.5"` and limit `"0.8"`. Select `spec.kai.gpuSharingMode: NvFractions` explicitly; the default remains `HamiCore`. Use fractional ceilings below `1`, such as `"0.99999"`, and eviction-based resize as described in [GPU sharing with KAI](./docs/GPU-Sharing-with-KAI.md).

### Migrate strategy permissions

Before, a request-only strategy might contain:

```yaml
spec:
  enablement:
    gpu:
      requests:
        upsize: true
```

After, on the referenced `ClusterAutomationStrategy`, enable each desired direction separately for requests and limits. This example permits increases only:

```yaml
apiVersion: rightsizing.kubex.ai/v1alpha1
kind: ClusterAutomationStrategy
metadata:
  name: gpu-resize
spec:
  enablement:
    gpu:
      requests:
        upsize: true
      limits:
        upsize: true
```

The namespaced `AutomationStrategy` uses the same fields. Enable only the directions you intend to allow. After bounds, every changing member needs its applicable `upsize`, `downsize`, or `setFromUnspecified` permission. An unchanged member must still have an explicit target, but needs no direction permission. For example, changing request `"0.4"` to `"0.5"` while retaining limit `"0.8"` requires both targets but only request upsize permission.

If either changing member of a valid selected pair is direction-disabled, neither GPU member changes, but unrelated CPU and memory changes can still proceed. Incomplete or invalid selected pairs instead fail validation and block the entire resize plan, including CPU and memory changes. Proactive and GPU reactive recommendations now emit equal explicit pairs, but those pairs still require permission for every changing member. With NvFractions, an equal pair removes an existing burst limit, so limit downsize permission may be required even when the request is unchanged.

### Migrate legacy Helm values

Before:

```yaml
policy:
  policies:
    gpu-resize:
      enablement:
        gpu:
          request:
            upsize: true
```

After:

```yaml
policy:
  policies:
    gpu-resize:
      enablement:
        gpu:
          requests:
            upsize: true
          limits:
            upsize: true
```

Helm now renders explicit GPU limit permissions and bounds. `request` / `requests` and `limit` / `limits` are supported aliases; non-empty plural forms take precedence. No limit block is synthesized when omitted. Request-only settings stop GPU resizing whenever the limit must also change, including native NVIDIA and HAMi-core, not just NvFractions.

Static policy users must check both selected targets and strategy permissions. Successful CPU or memory planning does not prove GPU resizing occurred. The legacy Helm template still does not expose new GPU sharing settings; configure those directly on strategy resources.

See [static policies](./docs/Static-Policies.md#gpu-requests-and-limits), [automation strategies](./docs/Automation-Strategies.md#kai-gpu-sharing-and-vllm-tuning), and [cluster automation strategies](./docs/Cluster-Automation-Strategies.md) for the shared semantics.

## Next release: GPU/KAI contract removal

Remove `spec.experimental` from GPU/KAI resources and `experimental.gpuKaiContract` from Helm values. GPU/KAI configuration no longer requires an acknowledgement token. GPU action enablement remains disabled by default; keep each desired action explicitly enabled under `spec.enablement.gpu`. This supersedes the historical contract migration instructions below.

## Upgrading to 1.18.0 or later: rollback recovery may bypass PodDisruptionBudgets

When a resize rollback is recovering a workload, the controller recreates pods that have not
adopted the persisted rollback target, one at a time. It first uses the Kubernetes Eviction API.
If the API explicitly reports that a PodDisruptionBudget blocked that eviction, the controller
deletes the pod gracefully so the workload can replace it with one running the rollback target.
This fallback can temporarily take the workload below its PDB's availability allowance; the pod's
termination grace period is still honored. Other eviction errors, including generic API throttling,
do not trigger deletion.

Review PDBs for workloads that use automatic resize rollback and account for this recovery behavior
in availability expectations. No manifest migration is required.

## Upgrading from versions earlier than 1.9.0 to the latest release: GPU reactive policy rename

GPU policy resources and global setting were hard-renamed:

- `GpuRebalancingPolicy` → `GpuReactivePolicy`
- `ClusterGpuRebalancingPolicy` → `ClusterGpuReactivePolicy`
- `gpurebalancingpolicies` → `gpureactivepolicies`
- `clustergpurebalancingpolicies` → `clustergpureactivepolicies`
- `gpuRebalancingCheckInterval` → `gpuReactiveCheckInterval`

Kubernetes does not allow changing an established CRD's `spec.names.kind`. No compatibility CRDs, conversion webhook, or automatic migration are provided. Migrate in this order:

1. Export existing GPU policies if needed and convert saved manifests to the new kinds and resource names.
2. Delete old GPU policy objects while the old controller still runs.
3. Wait for policy finalizers and workload recommendation cleanup to finish. If the old controller is no longer running, manually remove stale workload annotations under `gpurebalancing.rightsizing.kubex.ai/` and `cwgpurebalancing.rightsizing.kubex.ai/`.
4. Delete the existing `gpurebalancingpolicies.rightsizing.kubex.ai` and `clustergpurebalancingpolicies.rightsizing.kubex.ai` CRDs.
5. Install the regenerated CRDs.
6. Upgrade the controller using renamed `globalConfiguration.gpuReactiveCheckInterval` Helm value.
7. Apply policies using `GpuReactivePolicy` and `ClusterGpuReactivePolicy`, and update external `PolicyEvaluation` and proposal manifests to reference those kinds.

> **Warning:** Do not delete existing CRDs before old policy objects finish cleanup. Their finalizers lose their controller and can leave resources stuck terminating.

## Upgrading from versions earlier than 1.8.0 to the latest release: GPU enablement defaults and experimental contract

GPU request actions now default to disabled. The following fields changed from `true` to `false`:

- `spec.enablement.gpu.requests.downsize`
- `spec.enablement.gpu.requests.upsize`
- `spec.enablement.gpu.requests.setFromUnspecified`

The GPU/KAI experimental contract changed to `v1alpha1-2026-07`. The previous contract is no longer accepted.

Affected resources:

- `AutomationStrategy`
- `ClusterAutomationStrategy`
- `GpuRebalancingPolicy`
- `ClusterGpuRebalancingPolicy`
- `GpuConsolidationPolicy`

### Migration

For upgrades from a version earlier than 1.8.0 to the latest release, after upgrading the CRDs:

1. Replace the existing `spec.experimental.gpuKaiContract` value with `v1alpha1-2026-07` in every affected resource.
2. For `AutomationStrategy` and `ClusterAutomationStrategy`, explicitly set each desired GPU action under `spec.enablement.gpu.requests` to `true`. The GPU policy kinds only require the contract update in step 1.
3. Reapply affected resources.
