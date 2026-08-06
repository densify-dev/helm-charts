# Kubex Connector Helm Chart

This chart deploys the in-cluster connector used for cluster data interface.

It is intended to be installed through `kubex-automation-stack`.

It can deploy the websocket relay sidecar for connector traffic relaying. The connector talks to the local relay automatically when the relay sidecar is enabled, and the relay dials the public Kubex tunnel endpoint.

The chart supports two configuration modes:

- Standalone mode via `kubex.*` values for host and cluster name, with credentials sourced from secrets
- Stack-managed mode via the forwarder `ConfigMap` and `forwarderCredentialsSecretRef`

When installed through `kubex-automation-stack`, the chart reads the shared Kubex host, tenant, and cluster identity from the forwarder `ConfigMap` via `forwarderConfigMap.name`.

Stack-managed credentials are configured through `forwarderCredentialsSecretRef.name`.

Connector timing and relay wiring remain configurable:

- `heartbeatSeconds`
- `requestTimeoutSeconds`
- `kubex.url.host`
- `kubex.clusterName`
- `forwarderConfigMap.name`
- `forwarderCredentialsSecretRef.name`
- `forwarderCredentialsSecretRef.usernameKey`
- `forwarderCredentialsSecretRef.epasswordKey`
- `relay.enabled`
- `relay.listenAddr`
- `relay.connectPath`
- `relay.tlsCaSecretName`
- `relay.hostAliases`
