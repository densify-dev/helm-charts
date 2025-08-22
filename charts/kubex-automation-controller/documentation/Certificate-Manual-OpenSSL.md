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
O = Densify
OU = Webhook
CN = densify-webhook-service.densify.svc

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = densify-webhook-service.densify.svc
DNS.2 = densify-webhook-service.densify.svc.cluster.local
DNS.3 = densify-webhook-service
DNS.4 = densify-webhook-service.densify
EOF
```

Use OpenSSL to generate the server certificate and key with the configuration file:
```bash
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -config webhook-cert.conf -extensions v3_req
```

### Create a Kubernetes Secret:
```bash
kubectl create secret tls densify-automation-tls --cert=cert.pem --key=key.pem -n densify
```

### Set cert-manager to disabled in your values-edit.yaml file:
```yaml
certmanager:
  enabled: false
```

### Important Notes:
- The certificate **must** include the Kubernetes service DNS names in the Subject Alternative Names (SAN)
- Replace `densify` in the DNS names with your actual namespace if different
- The Common Name (CN) should match the primary service DNS name
- Without proper DNS names, you'll get "TLS handshake error: bad certificate" errors
- **Works on all Kubernetes clusters**: This method works identically on local clusters (kind, minikube) and cloud platforms (EKS, GKE, AKS, etc.)
- **Cloud platform compatibility**: Kubernetes internal DNS and service discovery work the same way across all platforms

### Cleanup (if needed):
```bash
# Remove the Kubernetes secret
kubectl delete secret densify-automation-tls -n densify

# Remove local certificate and configuration files
rm -f cert.pem key.pem webhook-cert.conf
```
