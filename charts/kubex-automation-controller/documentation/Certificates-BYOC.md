# Bring Your Own Certificates (BYOC)

If you have your own Certificate Authority or existing certificates, you can use them with the webhook. However, the certificate **must** include specific DNS names for Kubernetes webhook communication.

## Certificate Requirements

Your certificate must include the following DNS names in the Subject Alternative Names (SAN) field:

- `densify-webhook-service.densify.svc`
- `densify-webhook-service.densify.svc.cluster.local`
- `densify-webhook-service`
- `densify-webhook-service.densify`

**Important Notes:**
- The Common Name (CN) should be `densify-webhook-service.densify.svc`
- Without these DNS names, you'll get "TLS handshake error: bad certificate" errors
- The certificate must be valid for server authentication (Extended Key Usage: serverAuth)

## Steps to Use Your Certificate

1. **Verify your certificate includes the required DNS names:**
   ```bash
   openssl x509 -in your-cert.pem -text -noout | grep -A 10 "Subject Alternative Name"
   ```

2. **Create a Kubernetes Secret:**
   ```bash
   kubectl create secret tls densify-automation-tls --cert=your-cert.pem --key=your-key.pem -n densify
   ```

3. **Set cert-manager to disabled in your values-edit.yaml file:**
   ```yaml
   certmanager:
     enabled: false
   ```

## Troubleshooting

- **Certificate validation errors**: Ensure your certificate includes all required DNS names
- **Namespace mismatch**: Update DNS names if using a different namespace
- **CA bundle issues**: The Helm chart will automatically extract the CA from your certificate

## Alternative: Generate Compatible Certificate

If your existing certificate doesn't have the required DNS names, see:
- [Certificate-Manual-OpenSSL.md](Certificate-Manual-OpenSSL.md)
- [Certificate-Manual-CFSSL.md](Certificate-Manual-CFSSL.md)