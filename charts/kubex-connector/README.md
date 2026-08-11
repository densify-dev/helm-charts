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
