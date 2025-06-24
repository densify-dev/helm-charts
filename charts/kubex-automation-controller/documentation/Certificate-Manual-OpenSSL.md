## Using OpenSSL:

### Generate certificates manually:

Use OpenSSL to generate the server certificate and key
```bash
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
```

### Create a Kubernetes Secret:
```bash
kubectl create secret tls densify-automation-tls --cert=cert.pem --key=key.pem 
-n densify-automation
```

### Update the caBundle in the values-edit.yaml

Base64-encode the CA certificate and update caBundle in the `values-edit.yaml`
```bash
cat ca.pem | base64 -w 0
```


