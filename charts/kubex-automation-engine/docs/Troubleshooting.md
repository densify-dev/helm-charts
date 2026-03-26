# Troubleshooting

Use this sequence when rightsizing does not happen as expected.

For a consolidated map of the controller's safety gates, see [Safety Controls](./Safety-Controls.md).

## 1. Interpret `rightsizing summary` Logs

```bash
kubectl logs -n kubex -l control-plane=controller-manager -c manager --since=10m | grep 'rightsizing summary'
```

Focus on these fields:

- `rightsizingResult`
- `policy`
- `failedChecks`
- `appliedFilters`
- `summary`

Common outcomes:

- `RESIZED`: in-place resize applied
- `EVICTED`: eviction path used
- `BLOCKED_RETRYING`: blocked by a temporary condition
- `BLOCKED`: blocked or failed without retry
- `SKIPPED`: nothing actionable remained after evaluation

## 2. Check Global Health

```bash
kubectl get globalconfiguration global-config -o yaml
kubectl describe globalconfiguration global-config
```

Confirm:

- `spec.automationEnabled=true`
- webhook health condition is ready
- protected namespace patterns do not match the target namespace
- recommendation reloads are succeeding

If `POD_NAMESPACE` is missing in a custom deployment, startup fails fast.

## 3. Check Policy and Strategy Resolution

```bash
kubectl describe proactivepolicy -A
kubectl describe clusterproactivepolicy
kubectl describe automationstrategy -A
kubectl describe clusterautomationstrategy
```

Look for status and events indicating:

- resolved strategy reference
- invalid strategy reference
- strategy not found

## 4. Check Runtime Events

```bash
kubectl get events -A --field-selector reason=PrecheckFailed
kubectl get events -A --field-selector reason=PolicyEvaluationSelected
kubectl get events -A --field-selector reason=PolicyEvaluationSkipped
kubectl get events -A --field-selector reason=PolicyEvaluationInPlaceResize
kubectl get events -A --field-selector reason=PolicyEvaluationEvictResize
```

## 5. Common Blockers

- no valid Kubex recommendation for the target container
- recommendation older than `maxAnalysisAgeDays`
- pause annotation present
- HPA or VPA overlap
- ResourceQuota or LimitRange conflict
- node allocatable headroom gate
- pod readiness or workload availability protection
- webhook health probe failure

## 6. Verify Webhook Registration

```bash
kubectl get mutatingwebhookconfigurations.admissionregistration.k8s.io
```

Confirm the Kubex mutating webhook configuration exists and is accepted by the API server.
