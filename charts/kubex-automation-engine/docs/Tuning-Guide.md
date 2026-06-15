# Tuning Guide

Use this guide when you need Kubex Automation Engine to stay predictable on slower, larger, or more constrained clusters.

## Purpose and Tuning Philosophy

Tune only the parts that match the failure mode you are seeing:

- increase control plane tolerance when leader election or reconciles are unstable
- increase admission tolerance when webhook API calls are slow or throttled
- increase external dependency tolerance when Kubex or Prometheus calls take longer
- increase resource and placement resilience when the controller is starved or frequently rescheduled

Prefer small changes, validate them, and keep rollback values ready.

## What “Slow Cluster Tolerance” Means

In this chart, slow cluster tolerance means the controller and webhooks continue operating safely when:

- Kubernetes API requests are slow or bursty
- leader election renewals are delayed
- admission webhook owner lookups take longer
- the controller is CPU or memory constrained
- nodes are under pressure, tainted, or uneven across zones

The goal is usually graceful degradation, not forcing every operation to succeed immediately.

## Exposed Helm/Runtime Knobs

Validate all tuning changes against these implementation-backed settings.

### Control Plane Tolerance

- `controllerManager.leaderElection.leaseDuration`
- `controllerManager.leaderElection.renewDeadline`
- `controllerManager.leaderElection.retryPeriod`
- `controllerManager.globalConfigReconcileInterval`
- `controllerManager.extraArgs` for:
  - `--kube-api-qps`
  - `--kube-api-burst`
  - `--max-concurrent-reconciles`
  - `--pprof-bind-address`

Notes:

- leader election values are rendered into manager args in `templates/_helpers.tpl`
- `globalConfigReconcileInterval` is passed as `GLOBAL_CONFIG_RECONCILE_INTERVAL` in `templates/deployment.yaml`
- `extraArgs` is appended directly to the manager command line in `templates/_helpers.tpl`

### Admission/Webhook Tolerance

- `webhook.timeoutSeconds`
- `controllerManager.podAdmissionWebhookKubeAPIQPS`
- `controllerManager.podAdmissionWebhookKubeAPIBurst`
- `globalConfiguration.webhookOwnerResolutionRetryTimeout`
- `globalConfiguration.webhookHealth.failureThreshold`
- `globalConfiguration.webhookHealth.successThreshold`
- `globalConfiguration.webhookHealth.transitionCheckInterval`
- `globalConfiguration.webhookProbe.image`
- `globalConfiguration.webhookProbe.labels`
- `globalConfiguration.webhookProbe.annotations`
- `globalConfiguration.webhookProbe.resources`
- `globalConfiguration.webhookProbe.podSecurityContext`
- `globalConfiguration.webhookProbe.securityContext`

Notes:

- `controllerManager.podAdmissionWebhookKubeAPIQPS` defaults to `-1`, which disables client-side rate limiting for the pod admission webhook client
- `controllerManager.podAdmissionWebhookKubeAPIBurst` defaults to `0`; with QPS disabled, this is not acting as a practical cap by default
- lowering the webhook client from the default unlimited behavior to a small positive QPS can introduce client-side throttling and increase missed mutation during API slowness
- use these settings mainly when you intentionally want to cap or shape webhook API pressure, not as a default throughput optimization

### Admission Webhook Fail-Open Semantics

The pod mutating webhook is fail-open.

- Pod mutation uses `failurePolicy: Ignore` in `templates/mutatingwebhook.yaml`
- Pod creation continues even if the webhook hits Kubernetes API communication failures
- Pod creation continues even if the webhook hits internal or runtime errors
- The result is missed mutation, not blocked admission
- Proactive automation can still pause later if webhook health becomes unhealthy

This matches the implementation in `internal/webhook/v1alpha1/podrightsizing_webhook.go`, where the webhook logs admission errors but always returns `nil` from `Default()`.

Validating webhooks are also fail-open by default, but configurable:

- `templates/validatingwebhook.yaml` uses `failurePolicy: {{ .Values.webhook.failurePolicy }}`
- `values.yaml` defaults `webhook.failurePolicy` to `Ignore`
- operators can change that behavior if they intentionally want stricter validation semantics

### External Dependency Tolerance

- `globalConfiguration.kubexAPIRequestTimeout`
- `globalConfiguration.prometheus.requestTimeout`
- `globalConfiguration.recommendationReloadInterval`
- `globalConfiguration.rescanInterval`

### Resource and Placement Resilience

- `resources`
- `gateway.resources`
- `livenessProbe`
- `readinessProbe`
- `replicaCount`
- `nodeSelector`
- `tolerations`
- `affinity`
- `topologySpreadConstraints`

## Scenario-Based Tuning Playbooks

### Very Slow API Server / Unstable Leader Election

Symptoms:

- controller restarts or leadership changes during API slowness
- reconcile gaps after short control plane stalls

Tune:

- increase `controllerManager.leaderElection.leaseDuration`
- increase `controllerManager.leaderElection.renewDeadline`
- increase `controllerManager.leaderElection.retryPeriod`
- consider slightly increasing `controllerManager.globalConfigReconcileInterval`

Example:

```yaml
controllerManager:
  leaderElection:
    leaseDuration: 60s
    renewDeadline: 40s
    retryPeriod: 10s
  globalConfigReconcileInterval: 2m
```

### Slow Admission Path on Very Slow API Server

Symptoms:

- webhook health flaps during API slowness
- new pods are admitted but miss mutation more often
- webhook logs show API timeout or throttling behavior

Tune:

- increase `webhook.timeoutSeconds`
- increase `globalConfiguration.webhookOwnerResolutionRetryTimeout`
- increase webhook health tolerance before marking unhealthy
- leave `controllerManager.podAdmissionWebhookKubeAPIQPS: -1` unless you intentionally want a client-side cap
- if you do need a cap, set `controllerManager.podAdmissionWebhookKubeAPIQPS` and `controllerManager.podAdmissionWebhookKubeAPIBurst` high enough that they do not become the new bottleneck

Example:

```yaml
webhook:
  timeoutSeconds: 20

controllerManager:
  podAdmissionWebhookKubeAPIQPS: -1
  podAdmissionWebhookKubeAPIBurst: 0

globalConfiguration:
  webhookOwnerResolutionRetryTimeout: 5s
  webhookHealth:
    failureThreshold: 5
    successThreshold: 2
    transitionCheckInterval: 10s
```

`successThreshold: 2` recovers webhook health faster after transient API stalls. `successThreshold: 3` is more conservative and recovers slower. This example uses `2` deliberately for very slow API server scenarios; chart default remains `3`.

Combined very slow API server example:

```yaml
webhook:
  timeoutSeconds: 20
controllerManager:
  leaderElection:
    leaseDuration: 60s
    renewDeadline: 40s
    retryPeriod: 10s
  podAdmissionWebhookKubeAPIQPS: -1
  podAdmissionWebhookKubeAPIBurst: 0
  globalConfigReconcileInterval: 2m
globalConfiguration:
  webhookOwnerResolutionRetryTimeout: 5s
  rescanInterval: 12h
  webhookHealth:
    failureThreshold: 5
    successThreshold: 2
    transitionCheckInterval: 10s
```

### Restrictive Admission Environment Blocking Webhook Probe Pods

Symptoms:

- webhook health stays unhealthy
- dry-run probe pods are denied by image policy, pod security policy, or admission controls
- proactive automation pauses even though the webhook server is reachable

Tune:

- set an allowed `globalConfiguration.webhookProbe.image`
- add required `globalConfiguration.webhookProbe.labels` or `annotations`
- add compliant `globalConfiguration.webhookProbe.resources`
- set `globalConfiguration.webhookProbe.podSecurityContext` and `securityContext` to match cluster requirements

Example:

```yaml
globalConfiguration:
  webhookProbe:
    image: registry.example.com/mirrors/densify/automation-controller:1.3.1
    labels:
      eks.amazonaws.com/skip-pod-identity-webhook: "true"
    annotations:
      policy.example.com/allow-webhook-probe: "true"
    resources:
      requests:
        cpu: 10m
        memory: 32Mi
    podSecurityContext:
      runAsNonRoot: true
      seccompProfile:
        type: RuntimeDefault
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
```

### Controller CPU/Memory Starvation

Symptoms:

- slow reconciles
- pod restarts from OOMKills
- delayed webhook handling during bursts

Tune:

- increase `resources`
- increase `gateway.resources` if recommendation fetch or gateway processing is the bottleneck
- review `livenessProbe` and `readinessProbe` timing only if restarts are probe-related rather than actual crashes
- consider `replicaCount: 2` or higher together with stable placement and leader election tolerance

### Large/Noisy Clusters with Throttling or Backlog

Symptoms:

- client-side throttling
- reconcile backlog during cluster churn
- webhook owner lookups slowed by API contention

Tune:

- add `controllerManager.extraArgs` for `--kube-api-qps` and `--kube-api-burst`
- add `controllerManager.extraArgs` for `--max-concurrent-reconciles`
- keep the webhook client at its default unlimited setting unless you intentionally need a cap there too
- avoid pushing concurrency so high that the controller becomes CPU starved

Example:

```yaml
controllerManager:
  podAdmissionWebhookKubeAPIQPS: -1
  podAdmissionWebhookKubeAPIBurst: 0
  extraArgs:
    - --zap-log-level=info
    - --kube-api-qps=100
    - --kube-api-burst=200
    - --max-concurrent-reconciles=20
    - --pprof-bind-address=:6060
```

### Node Pressure / Taints / Zone Instability

Symptoms:

- controller pods evicted or rescheduled frequently
- all replicas land on one unstable node or zone
- infra or dedicated ops nodes require explicit tolerations/selectors

Tune:

- set `nodeSelector`, `tolerations`, and `affinity`
- add `topologySpreadConstraints`
- increase `replicaCount` for better availability
- size `resources` so placement on infra nodes remains schedulable

Example:

```yaml
replicaCount: 2

nodeSelector:
  node-role.kubernetes.io/infra: ""

tolerations:
  - key: node-role.kubernetes.io/infra
    operator: Exists
    effect: NoSchedule

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          topologyKey: kubernetes.io/hostname
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: kubex-automation-engine

topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: kubex-automation-engine
```

## Example Values Snippets

### Very Slow API Server

```yaml
controllerManager:
  leaderElection:
    leaseDuration: 60s
    renewDeadline: 40s
    retryPeriod: 10s
  globalConfigReconcileInterval: 2m
```

### Slow Admission Path on Very Slow API Server

```yaml
webhook:
  timeoutSeconds: 20

controllerManager:
  podAdmissionWebhookKubeAPIQPS: -1
  podAdmissionWebhookKubeAPIBurst: 0

globalConfiguration:
  webhookOwnerResolutionRetryTimeout: 5s
  webhookHealth:
    failureThreshold: 5
    successThreshold: 2
    transitionCheckInterval: 10s
```

### Combined Very Slow API Server

```yaml
webhook:
  timeoutSeconds: 20
controllerManager:
  leaderElection:
    leaseDuration: 60s
    renewDeadline: 40s
    retryPeriod: 10s
  podAdmissionWebhookKubeAPIQPS: -1
  podAdmissionWebhookKubeAPIBurst: 0
  globalConfigReconcileInterval: 2m
globalConfiguration:
  webhookOwnerResolutionRetryTimeout: 5s
  rescanInterval: 12h
  webhookHealth:
    failureThreshold: 5
    successThreshold: 2
    transitionCheckInterval: 10s
```

### Restrictive Probe Admission/Image Policy

```yaml
globalConfiguration:
  webhookProbe:
    image: registry.example.com/mirrors/densify/automation-controller:1.3.1
    labels:
      eks.amazonaws.com/skip-pod-identity-webhook: "true"
    annotations:
      policy.example.com/allow-webhook-probe: "true"
    resources:
      requests:
        cpu: 10m
        memory: 32Mi
    podSecurityContext:
      runAsNonRoot: true
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
```

### Large-Cluster Throttling

```yaml
controllerManager:
  podAdmissionWebhookKubeAPIQPS: -1
  podAdmissionWebhookKubeAPIBurst: 0
  extraArgs:
    - --zap-log-level=info
    - --kube-api-qps=100
    - --kube-api-burst=200
    - --max-concurrent-reconciles=20
    - --pprof-bind-address=:6060
```

### HA/Infra-Node Placement

```yaml
replicaCount: 2

resources:
  requests:
    cpu: 200m
    memory: 2Gi

gateway:
  resources:
    requests:
      cpu: 25m
      memory: 90Mi

nodeSelector:
  node-role.kubernetes.io/infra: ""

tolerations:
  - key: node-role.kubernetes.io/infra
    operator: Exists
    effect: NoSchedule

topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: kubex-automation-engine
```

## Validation Checklist

Before rollout:

- confirm each tuned knob is exposed in Helm values or passed via `controllerManager.extraArgs`
- confirm leader election ordering remains valid: `leaseDuration > renewDeadline > retryPeriod`
- confirm `webhook.timeoutSeconds` still fits your admission SLOs
- confirm probe pod image, labels, annotations, and security settings satisfy cluster policy
- confirm added concurrency does not exceed available CPU and memory
- confirm you did not accidentally introduce webhook client-side throttling by replacing the default `podAdmissionWebhookKubeAPIQPS: -1` with an unnecessarily low positive value
- confirm placement rules still allow scheduling in the target cluster

After rollout:

- check `kubectl get globalconfiguration global-config -o yaml`
- verify `status.conditions[type=PodAdmissionWebhookHealthy].status` becomes `True`
- inspect controller logs for leader election churn, API throttling, or repeated webhook-health transitions
- create a new test pod and verify whether mutation is applied as expected
- confirm degraded admission behavior matches expectations: pod creation should continue even if mutation is skipped

## Troubleshooting and Rollback

If tuning does not help:

- revert to the previous Helm values file or use `helm upgrade --reuse-values` with the prior settings
- back out aggressive concurrency or QPS increases first
- if webhook probe health is the issue, fix probe admission compatibility before changing broader automation settings
- if the cluster remains unstable, prefer slower but predictable settings over aggressive throughput tuning

Operator expectations for degraded clusters:

- pod mutation webhook failures should normally surface as missing mutation, not rejected pod creation
- proactive automation may still pause when webhook health becomes unhealthy
- validating webhook fail-open behavior depends on `webhook.failurePolicy`, which defaults to `Ignore`

Related docs:

- [Configuration Reference](./Configuration-Reference.md)
- [Getting Started](./Getting-Started.md)
- [Troubleshooting](./Troubleshooting.md)
- [Advanced Configuration](./Advanced-Configuration.md)
