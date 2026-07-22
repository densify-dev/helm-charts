# Breaking Changes

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
