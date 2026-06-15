# Frequently Asked Questions

Common questions about the current Kubex Automation Controller architecture and chart behavior.

# Quick Links

- [Frequently Asked Questions](#frequently-asked-questions)
- [Quick Links](#quick-links)
  - [Getting Started Questions](#getting-started-questions)
  - [Configuration Questions](#configuration-questions)
  - [Security and Safety Questions](#security-and-safety-questions)
  - [Troubleshooting Questions](#troubleshooting-questions)

---

## Getting Started Questions

### What is the minimum setup?

You need a Kubernetes cluster, Helm, Kubex connection details, and at least one workload with valid Kubex recommendations.

### Do I have to use CRDs directly?

No. You can start with Helm-managed `scope` and `policy.policies`, then move to direct CR management only if you need the full resource model.

### Can I keep my old values file?

Yes, selected legacy `deployment.controllerEnv` settings are still honored for backward compatibility.

### How do I uninstall without leaving CRs stuck in `Terminating`?

Delete externally managed policies and strategies before uninstalling the Helm release so the running controller can process their cleanup.

If any external CRs remain stuck, manually patch away their finalizers, then run `helm uninstall`. For the full sequence and example commands, see [Getting Started](./Getting-Started.md#uninstall).

## Configuration Questions

### What is the difference between strategy and policy?

- strategy defines how changes are allowed to happen
- policy defines where the strategy applies and which recommendations are considered

### How does rollback recommendation lifecycle work?

Rollback recommendation state is scoped to a single turn. The controller keeps the rollback state annotation while an owner is in `backingOff`, and clears only the rollback recommendation annotations when that turn completes in `backedOff` or `failedPermanent`. A clean monitoring window ends in `monitoringSucceeded` and remains visible until a new recommendation or failure appears. Turn timing is controlled by `spec.backoff`, which sets the base duration, turn multiplier, and max attempts. When the same fingerprint is applied again after the prior turn has completed, it starts a fresh turn.

### Can Helm-managed and manual CRs coexist?

Yes. A common pattern is Helm for the baseline and manual CRs for workload-specific exceptions.

### How do I stop automation quickly?

Set `globalConfiguration.automationEnabled: false` and run `helm upgrade`, or scale down the controller as an emergency action.

### Where do I tune behavior for slow or constrained clusters?

Use the [Tuning Guide](./Tuning-Guide.md) for leader election tolerance, webhook/API latency, probe pod admission constraints, cluster throttling, and HA placement.

## Security and Safety Questions

### What prevents unsafe resizes?

The controller filters or blocks actions based on webhook health, protected namespaces, pause annotations, HPA/VPA detection, quota and LimitRange checks, node headroom, and workload readiness checks. Pause annotations can be set directly on a pod or on a supported workload owner, in which case new pods inherit them during admission and existing owned pods are reconciled to the same pause state.

For the complete safety model and where each control is configured, see [Safety Controls](./Safety-Controls.md).

### Does the controller mutate system namespaces?

Not by default. Protected namespace patterns exclude well-known platform namespaces unless you intentionally change that configuration.

## Troubleshooting Questions

### Where should I look first if nothing happens?

Check `GlobalConfiguration`, policy objects, events, and `rightsizing summary` logs in that order. If new pods are being created but expected mutation is missing, also review the webhook fail-open notes in the [Tuning Guide](./Tuning-Guide.md#admission-webhook-fail-open-semantics).

### Why is a matching policy not enough?

Because the controller still needs a valid recommendation and a plan that survives all strategy and safety filters.
