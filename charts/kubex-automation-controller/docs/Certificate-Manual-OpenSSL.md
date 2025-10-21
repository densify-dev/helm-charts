## Using OpenSSL:

### Prerequisites:

OpenSSL is typically pre-installed on most systems. Verify it's available:
```bash
openssl version
```

If OpenSSL is not installed:
```bash
# On Ubuntu/Debian:
sudo apt update && sudo apt install openssl

# On CentOS/RHEL/Fedora:
sudo dnf install openssl  # or sudo yum install openssl

# On macOS with Homebrew:
brew install openssl

# On Windows:
# Download from https://slproweb.com/products/Win32OpenSSL.html
# or use Windows Subsystem for Linux (WSL)
```

### Generate certificates manually:

First, create a configuration file for the certificate with the correct DNS names:
```bash
cat > webhook-cert.conf << 'EOF'
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Kubex
OU = Webhook
CN = kubex-webhook-service.kubex.svc

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = kubex-webhook-service.kubex.svc
DNS.2 = kubex-webhook-service.kubex.svc.cluster.local
DNS.3 = kubex-webhook-service
DNS.4 = kubex-webhook-service.kubex
EOF
```

Use OpenSSL to generate the server certificate and key with the configuration file:
```bash
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -config webhook-cert.conf -extensions v3_req
```

### Create a Kubernetes Secret:

**Important**: The secret must include the CA certificate. Since you generated a self-signed certificate, the certificate itself acts as the CA:

```bash
# Create secret with certificate, key, and CA certificate
kubectl create secret generic kubex-automation-tls \
  --from-file=tls.crt=cert.pem \
  --from-file=tls.key=key.pem \
  --from-file=ca.crt=cert.pem \
  -n kubex
```

**Note**: For self-signed certificates, `ca.crt` and `tls.crt` are the same file since the certificate acts as its own CA.

### Set cert-manager to disabled in your kubex-automation-values.yaml file:
```yaml
certmanager:
  enabled: false
```

### Important Notes:
- The certificate **must** include the Kubernetes service DNS names in the Subject Alternative Names (SAN)
- Replace `kubex` in the DNS names with your actual namespace if different
- The Common Name (CN) should match the primary service DNS name
- Without proper DNS names, you'll get "TLS handshake error: bad certificate" errors
- **Works on all Kubernetes clusters**: This method works identically on local clusters (kind, minikube) and cloud platforms (EKS, GKE, AKS, etc.)
- **Cloud platform compatibility**: Kubernetes internal DNS and service discovery work the same way across all platforms

### Cleanup (if needed):
```bash
# Remove the Kubernetes secret
kubectl delete secret kubex-automation-tls -n kubex

# Remove local certificate and configuration files
rm -f cert.pem key.pem webhook-cert.conf
```
