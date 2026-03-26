# Known Issues

This document lists current limitations and behavior notes for the CRD-based controller.

## Current Limitations

- Helm-managed configuration generates `ClusterAutomationStrategy` and `ClusterProactivePolicy`, but not the full set of namespaced and static policy resource types
- Some advanced strategy fields are available only through direct CR management, not through `policy.policies`
- Proactive automation requires valid Kubex recommendations; if no recommendation exists, matching policy alone does nothing
- Webhook health gating intentionally pauses proactive execution when the admission mutation path is unhealthy

### LimitRange `maxLimitRequestRatio` Not Supported

- Status: Known limitation
- Description: The controller does not currently validate or respect the `maxLimitRequestRatio` field in `LimitRange` objects when performing resource optimizations.
- Impact: Resource changes may violate `LimitRange` ratio constraints, which can cause pod admission failures.
- Root cause: Current validation logic checks min/max values but does not evaluate ratio constraints between requests and limits.
- Workaround: Exclude namespaces containing `LimitRange` objects with `maxLimitRequestRatio` constraints from your automation scope configuration.
- Planned fix: Extend `LimitRange` validation to enforce `maxLimitRequestRatio` checks.

## Operational Notes

- Overlapping scopes can make winner selection harder to reason about; users should not change `precedence` and should use `weight` instead
- Protected namespace patterns configured in [Global Configuration](./Global-Configuration.md) are enforced even if a broad policy selector would otherwise match them
- Legacy `deployment.controllerEnv` values remain supported only for the settings still mapped by the chart
- If recommendation reload succeeds with zero entries, proactive reconciliation is paused to avoid clearing previously written proactive recommendation state

## Future Enhancements

### Introduce Reactive Policies

- Reactive policies to detect when a resize leaves a pod in a degraded or unhealthy state and automatically revert the last resize action
- Reactive handling for OOM kill scenarios so proactive policy logic can increase memory allocations automatically when appropriate
- Guardrails on automatic memory increases to prevent unbounded growth in cases such as persistent memory leaks
