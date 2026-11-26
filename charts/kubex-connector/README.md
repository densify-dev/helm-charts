# kubex-connector chart

Deploys the customer-side connector that dials proxy `/tunnel/connect` and forwards traffic to local upstream.

Set `connectorServices` (a YAML list) to define one or more service IDs and upstream URLs. Keep environment-specific values in a separate, private values file.

`connectorServices` is required.

## Architecture

The connector is a customer-cluster tunnel agent. It does not expose public ingress by itself.

- Establishes a persistent WebSocket tunnel to proxy at `/tunnel/connect`
- Identifies itself with `CONNECTOR_TENANT_ID` and `CONNECTOR_CLUSTER_ID`
- Registers one or more service IDs from `connectorServices` (rendered to `CONNECTOR_SERVICES_JSON` in the deployment)
- Receives proxied requests for `/proxy/:tenant/:cluster/:service/*`
- Forwards each request to the matching local upstream URL in the customer cluster
- Returns status, headers, and body back through the same tunnel

## Metrics

Both containers serve Prometheus metrics at `/metrics`:

| Container | Metric | Port name | Port value |
| --- | --- | --- | --- |
| connector | `kubex_connector_build_info` | `metrics` | `metricsPort` (default `9090`) |
| `relay` | `kubex_automation_gateway_build_info` | `relay-metrics` | `relay.metricsPort` (default `8182`) |

Each value sets both the container port and the matching listen address (`CONNECTOR_METRICS_ADDR` or `METRICS_ADDR`), so set the port through these values rather than `env` or `extraEnv`; the chart rejects those overrides. Both containers share the pod's network namespace, so the chart also rejects a `metricsPort` or `relay.metricsPort` that collides with the other or with `relay.listenAddr`. A container exits at startup if it cannot bind its metrics port.

## Deploy

```bash
kubectl config use-context <KUBEX_CUSTOMER_CONTEXT>
kubectl --context <KUBEX_CUSTOMER_CONTEXT> create namespace kubex-ai --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install kubex-connector ./charts/kubex-connector \
  --namespace kubex-ai \
  -f ./values-private.yaml
```

## Verify

```bash
kubectl --context <KUBEX_CUSTOMER_CONTEXT> -n kubex-ai get pods
kubectl --context <KUBEX_CUSTOMER_CONTEXT> -n kubex-ai logs deploy/kubex-connector-deployment
```
