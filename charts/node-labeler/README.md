# node-labeler

Helm chart to deploy the `node-labeler` Kubernetes controller.

## Prerequisites

- Kubernetes 1.27+
- Helm 3.x

## Install

```sh
helm upgrade --install node-labeler ./charts/node-labeler -n kubex-system --create-namespace
```

## Upgrade

```sh
helm upgrade node-labeler ./charts/node-labeler -n kubex-system
```

## Notes

- The chart deploys into the Helm release namespace.
- Machine API RBAC (`machine.openshift.io`) is included; the controller self-detects API availability at runtime.
- Metrics Service is disabled by default.
- This chart can be deployed standalone but is not meant to. It is installed as a dependency of the `kubex-automation-stack` umbrella chart.

## Values

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `image.repository` | string | `densify/node-labeler` | Controller image repository |
| `image.tag` | string | `latest` | Controller image tag |
| `image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `serviceAccount.create` | bool | `true` | Create service account |
| `serviceAccount.name` | string | `""` | Existing service account name when create is false |
| `rbac.create` | bool | `true` | Create RBAC resources |
| `leaderElection.enabled` | bool | `true` | Enable leader election flag |
| `metrics.enabled` | bool | `false` | Expose metrics endpoint/service |
| `metrics.secure` | bool | `true` | Serve metrics over HTTPS when enabled |
| `metrics.bindAddress` | string | `:8443` | Metrics bind address |
| `healthProbe.bindAddress` | string | `:8081` | Health/readiness probe bind address |
| `resources` | object | see `values.yaml` | Pod resource requests/limits |
| `extraArgs` | list | `[]` | Extra manager CLI args |
