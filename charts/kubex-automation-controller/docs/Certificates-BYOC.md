# Bring Your Own Certificates (BYOC)

If you have your own Certificate Authority or existing certificates, you can use them with the webhook. However, the certificate **must** include specific DNS names for Kubernetes webhook communication.

## Certificate Requirements

Your certificate must include the following DNS names in the Subject Alternative Names (SAN) field:

- `kubex-webhook-service.kubex.svc`
- `kubex-webhook-service.kubex.svc.cluster.local`
- `kubex-webhook-service`
- `kubex-webhook-service.kubex`

**Important Notes:**
- The Common Name (CN) should be `kubex-webhook-service.kubex.svc`
- Without these DNS names, you'll get "TLS handshake error: bad certificate" errors
- The certificate must be valid for server authentication (Extended Key Usage: serverAuth)

## Steps to Use Your Certificate

1. **Verify your certificate includes the required DNS names:**
   ```bash
   openssl x509 -in your-cert.pem -text -noout | grep -A 10 "Subject Alternative Name"
   ```

2. **Create a Kubernetes Secret with CA Certificate:**
   
   Your secret **must** include the CA certificate that signed your TLS certificate. The Kubex automation controller requires the CA certificate to validate webhook communications.
   
   ```bash
   # Create the secret with TLS certificate, key, AND CA certificate
   kubectl create secret generic kubex-automation-tls \
     --from-file=tls.crt=your-cert.pem \
     --from-file=tls.key=your-key.pem \
     --from-file=ca.crt=your-ca.pem \
     -n kubex
   ```
   
   **Important**: The secret must contain all three files:
   - `tls.crt`: Your TLS certificate
   - `tls.key`: Your private key  
   - `ca.crt`: The CA certificate that signed `tls.crt`

3. **Set cert-manager to disabled in your kubex-automation-values.yaml file:**
   ```yaml
   certmanager:
     enabled: false
   ```

## Troubleshooting

- **Certificate validation errors**: Ensure your certificate includes all required DNS names
- **Namespace mismatch**: Update DNS names if using a different namespace  
- **CA bundle issues**: Verify your secret includes the `ca.crt` key with the correct CA certificate
- **Webhook admission failures**: Check that the `caBundle` in the MutatingWebhookConfiguration matches your CA certificate
- **Secret validation**: Verify your secret has the correct structure:
  ```bash
  kubectl get secret kubex-automation-tls -n kubex -o yaml
  # Should show data keys: ca.crt, tls.crt, tls.key
  ```

## Alternative: Generate Compatible Certificate

If your existing certificate doesn't have the required DNS names, see:
- [Certificate-Manual-OpenSSL.md](Certificate-Manual-OpenSSL.md)
- [Certificate-Manual-CFSSL.md](Certificate-Manual-CFSSL.md)