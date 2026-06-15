# Troubleshooting

Use this sequence when rightsizing does not happen as expected.

For a consolidated map of the controller's safety gates, see [Safety Controls](./Safety-Controls.md).

## 0. Temporarily Enable Debug Logging (and Revert)

Most of the time you only want debug logs briefly. The quickest way is to update the live Deployment args (this triggers a rollout and will be overwritten by the next `helm upgrade`).

Enable debug (temporary):

```bash
kubectl -n kubex patch deploy/$(kubectl -n kubex get deploy -l app.kubernetes.io/name=kubex-automation-engine -o jsonpath='{.items[0].metadata.name}') --type='json' -p='[{"op":"replace","path":"/spec/template/spec/containers/0/args/3","value":"--zap-log-level=debug"}]'
```

Revert back to info:

```bash
kubectl -n kubex patch deploy/$(kubectl -n kubex get deploy -l app.kubernetes.io/name=kubex-automation-engine -o jsonpath='{.items[0].metadata.name}') --type='json' -p='[{"op":"replace","path":"/spec/template/spec/containers/0/args/3","value":"--zap-log-level=info"}]'
```

If you want the setting to persist across upgrades, use Helm instead:

```bash
helm upgrade kubex-automation kubex/kubex-automation-engine -n kubex --reuse-values --set 'controllerManager.extraArgs[0]=--zap-log-level=debug'
```

Revert with Helm:

```bash
helm upgrade kubex-automation kubex/kubex-automation-engine -n kubex --reuse-values --set 'controllerManager.extraArgs[0]=--zap-log-level=info'
```

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

Important:

- pod webhook runtime or Kubernetes API communication failures usually show up as missed mutation, not rejected pod admission
- if those failures make webhook health unhealthy, proactive automation can still pause until probe health recovers
- validating webhook rejection behavior depends on `webhook.failurePolicy`, which defaults to `Ignore`

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
- `StrimziPodSet` not matching expected pods: verify the StrimziPodSet has a non-empty `spec.selector` and that the pods in the namespace actually match it.
- webhook health probe failure
- webhook probe dry-run pod denied by admission image policy (set `globalConfiguration.webhookProbe.image` to an allowed mirrored image)
- on EKS, verify your version includes probe pod label `eks.amazonaws.com/skip-pod-identity-webhook: "true"` to bypass the AWS pod identity webhook for this dry-run probe
- webhook runtime or API failures causing missing mutation on new pods while admission still succeeds; in that case inspect webhook-health gating and the [Tuning Guide](./Tuning-Guide.md#admission-webhook-fail-open-semantics)

## 6. Verify Webhook Registration

```bash
kubectl get mutatingwebhookconfigurations.admissionregistration.k8s.io
```

Confirm the Kubex mutating webhook configuration exists and is accepted by the API server.

For targeted slow-cluster and degraded-environment settings, see [Tuning Guide](./Tuning-Guide.md).
