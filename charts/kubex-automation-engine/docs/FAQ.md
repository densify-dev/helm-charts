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

### Can Helm-managed and manual CRs coexist?

Yes. A common pattern is Helm for the baseline and manual CRs for workload-specific exceptions.

### How do I stop automation quickly?

Set `globalConfiguration.automationEnabled: false` and run `helm upgrade`, or scale down the controller as an emergency action.

## Security and Safety Questions

### What prevents unsafe resizes?

The controller filters or blocks actions based on webhook health, protected namespaces, pause annotations, HPA/VPA detection, quota and LimitRange checks, node headroom, and workload readiness checks. Pause annotations can be set directly on a pod or on a supported workload owner, in which case new pods inherit them during admission and existing owned pods are reconciled to the same pause state.

For the complete safety model and where each control is configured, see [Safety Controls](./Safety-Controls.md).

### Does the controller mutate system namespaces?

Not by default. Protected namespace patterns exclude well-known platform namespaces unless you intentionally change that configuration.

## Troubleshooting Questions

### Where should I look first if nothing happens?

Check `GlobalConfiguration`, policy objects, events, and `rightsizing summary` logs in that order.

### Why is a matching policy not enough?

Because the controller still needs a valid recommendation and a plan that survives all strategy and safety filters.
