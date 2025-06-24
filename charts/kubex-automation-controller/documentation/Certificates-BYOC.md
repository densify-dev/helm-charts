# Bring Your Own Certificates (BYOC)

1. Ensure you have a valid certificate and key.
2. Create a Kubernetes Secret:
    ```bash
    kubectl create secret tls densify-automation-tls --cert=path-to-cert.pem --key=path-to-key.pem -n densify-automation
    ```
3. Update the caBundle in the values-edit.yaml
   
   Base64-encode the CA certificate and update caBundle in the `values-edit.yaml`
   ```bash
   cat ca.pem | base64 -w 0
   ```