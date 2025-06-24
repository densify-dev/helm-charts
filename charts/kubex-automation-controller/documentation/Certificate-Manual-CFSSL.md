## Using CFSSL:

### Install CFSSL

Download and install CFSSL and its companion tool CFSSLJSON:

```bash
curl -LO https://github.com/cloudflare/cfssl/releases/latest/download/cfssl
```
```bash
curl -LO https://github.com/cloudflare/cfssl/releases/latest/download/cfssljson
```
```bash
chmod +x cfssl cfssljson
```
```bash
sudo mv cfssl cfssljson /usr/local/bin/
```

Verify installation:
```bash
cfssl version
cfssljson --version
```
### Generate Certificates

Generate the CA certificate and key: 
```bash
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```

Generate the server certificate: 
```bash
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json \ 
-profile=default server-csr.json | cfssljson -bare server
```

### Create a Kubernetes Secret
```bash
kubectl create secret tls densify-automation-tls --cert=server.pem --key=server-key.pem -n densify-automation
```

### Update the caBundle in the values-edit.yaml

Base64-encode the CA certificate and update caBundle in the `values-edit.yaml`
```bash
cat ca.pem | base64 -w 0
```
