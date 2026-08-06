# Echo Test Example

This example deploys a tiny HTTP echo service in the connector cluster to validate end-to-end tunnel forwarding.

## Deploy echo service

```bash
kubectl config use-context <KUBEX_CUSTOMER_CONTEXT>
kubectl --context <KUBEX_CUSTOMER_CONTEXT> -n kubex-ai apply -f ./charts/kubex-connector/examples/kubex-echo.yaml
kubectl --context <KUBEX_CUSTOMER_CONTEXT> -n kubex-ai get pods,svc -l app=kubex-echo
```

## Configure connector

Ensure connector values include the `echo` service entry:

```yaml
connectorServices:
  - service_id: echo
    upstream_url: http://kubex-echo:8080
```

Then redeploy connector:

```bash
helm upgrade --install kubex-connector ./charts/kubex-connector \
  --namespace kubex-ai \
  -f ./charts/kubex-connector/values-dev.yaml
```

## Test via proxy

```bash
curl "http://172.18.0.3:31908/proxy/tenant-a/cluster-1/echo/hello?x=1" \
  -H "X-Test: one" \
  -d 'ping'
```

Expected: response includes echoed method/path/query/headers/body from `kubex-echo`.

Additional checks:

```bash
# GET with query preservation
curl "http://<KUBEX_NODE_IP>:31908/proxy/tenant-a/cluster-1/echo/health?check=true"

# Multi-header forwarding
curl "http://<KUBEX_NODE_IP>:31908/proxy/tenant-a/cluster-1/echo/headers" \
  -H "X-Trace: a" \
  -H "X-Trace: b"
```

Expected:

- `path` reflects the suffix (`/hello`, `/health`, `/headers`).
- query parameters are preserved.
- repeated header values are visible (`X-Trace: a` and `X-Trace: b`).
