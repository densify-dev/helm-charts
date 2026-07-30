# Breaking Changes

## 2026-07-21 GPU reactive policy rename

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

## 2026-07-20 - GPU enablement defaults and experimental contract

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

After upgrading the CRDs:

1. Replace the existing `spec.experimental.gpuKaiContract` value with `v1alpha1-2026-07` in every affected resource.
2. For `AutomationStrategy` and `ClusterAutomationStrategy`, explicitly set each desired GPU action under `spec.enablement.gpu.requests` to `true`. The GPU policy kinds only require the contract update in step 1.
3. Reapply affected resources.
