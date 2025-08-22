## Using CFSSL:

### Install CFSSL

Download and install CFSSL and its companion tool CFSSLJSON:

**For Linux (x86_64/amd64):**
```bash
curl -LO https://github.com/cloudflare/cfssl/releases/latest/download/cfssl_1.6.5_linux_amd64
curl -LO https://github.com/cloudflare/cfssl/releases/latest/download/cfssljson_1.6.5_linux_amd64
mv cfssl_1.6.5_linux_amd64 cfssl
mv cfssljson_1.6.5_linux_amd64 cfssljson
```

**For macOS (Intel):**
```bash
curl -LO https://github.com/cloudflare/cfssl/releases/latest/download/cfssl_1.6.5_darwin_amd64
curl -LO https://github.com/cloudflare/cfssl/releases/latest/download/cfssljson_1.6.5_darwin_amd64
mv cfssl_1.6.5_darwin_amd64 cfssl
mv cfssljson_1.6.5_darwin_amd64 cfssljson
```

**For macOS (Apple Silicon/M1/M2):**
```bash
curl -LO https://github.com/cloudflare/cfssl/releases/latest/download/cfssl_1.6.5_darwin_arm64
curl -LO https://github.com/cloudflare/cfssl/releases/latest/download/cfssljson_1.6.5_darwin_arm64
mv cfssl_1.6.5_darwin_arm64 cfssl
mv cfssljson_1.6.5_darwin_arm64 cfssljson
```

**Alternative: Use package managers**
```bash
# On Ubuntu/Debian:
sudo apt install golang-cfssl

# On macOS with Homebrew:
brew install cfssl

# On CentOS/RHEL/Fedora:
sudo dnf install cfssl  # or sudo yum install cfssl
```

**Check your system architecture (if unsure):**
```bash
uname -sm  # Shows OS and architecture
```
**Make the binaries executable and install (for manual download only):**
```bash
chmod +x cfssl cfssljson
sudo mv cfssl cfssljson /usr/local/bin/
```

**Verify installation:**
```bash
cfssl version
cfssljson --version
```
### Generate Certificates

First, create the required configuration files:

#### 1. Create CA Certificate Signing Request (ca-csr.json):
```bash
cat > ca-csr.json << 'EOF'
{
  "CN": "Densify Webhook CA",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "City",
      "O": "Densify",
      "OU": "Webhook",
      "ST": "State"
    }
  ]
}
EOF
```

#### 2. Create CA Configuration (ca-config.json):
```bash
cat > ca-config.json << 'EOF'
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "default": {
        "usages": ["signing", "key encipherment", "server auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF
```

#### 3. Create Server Certificate Signing Request (server-csr.json):
```bash
cat > server-csr.json << 'EOF'
{
  "CN": "densify-webhook-service.densify.svc",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "City",
      "O": "Densify",
      "OU": "Webhook",
      "ST": "State"
    }
  ],
  "hosts": [
    "densify-webhook-service",
    "densify-webhook-service.densify",
    "densify-webhook-service.densify.svc",
    "densify-webhook-service.densify.svc.cluster.local"
  ]
}
EOF
```

Now generate the certificates:

Generate the CA certificate and key: 
```bash
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```

Generate the server certificate: 
```bash
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=default server-csr.json | cfssljson -bare server
```

### Create a Kubernetes Secret
```bash
kubectl create secret tls densify-automation-tls --cert=server.pem --key=server-key.pem -n densify
```

### Set cert-manager to disabled in your values-edit.yaml file:
```yaml
certmanager:
  enabled: false
```

### Important Notes:
- The server certificate **must** include the Kubernetes service DNS names in the "hosts" field
- The Common Name (CN) should match the primary service DNS name
- Without proper DNS names, you'll get "TLS handshake error: bad certificate" errors
- The CA certificate will be automatically extracted and used by the Helm chart when `certmanager.enabled: false`
- **Works on all Kubernetes clusters**: This method works identically on local clusters (kind, minikube) and cloud platforms (EKS, GKE, AKS, etc.)
- **Cloud platform compatibility**: Kubernetes internal DNS and service discovery work the same way across all platforms

### Cleanup (if needed):
```bash
# Remove the Kubernetes secret
kubectl delete secret densify-automation-tls -n densify

# Remove local certificate and configuration files
rm -f ca.pem ca-key.pem ca.csr server.pem server-key.pem server.csr ca-csr.json ca-config.json server-csr.json
```