#!/bin/bash

set -e

print_usage() {
  echo "Usage:"
  echo "  ./deploy-kubex-automation-controller.sh [--certmanager] [--openshift] [--uninstall]"
  echo
  echo "Options:"
  echo "  --certmanager       Use cert-manager for certificate management instead of self-signed certificates."
  echo "                      NOTE: cert-manager must be pre-installed in your cluster."
  echo
  echo "  --openshift         Deploy using OpenShift-specific values (values-openshift.yaml)."
  echo "                      This enables OpenShift-specific service account settings."
  echo
  echo "  --uninstall         Uninstalls the kubex-automation-controller Helm release."
  echo
  echo "By default, self-signed certificates with 10-year validity are automatically generated."
  echo
}



# Default values
NAMESPACE="kubex"
CERT_MANAGER_ACTION=false
DELETE_MODE=false
OPENSHIFT_MODE=false

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --certmanager)
      CERT_MANAGER_ACTION=true
      ;;
    --openshift)
      OPENSHIFT_MODE=true
      ;;
    --uninstall)
      DELETE_MODE=true
      ;;
    -* )
      echo "Unknown parameter passed: $1"
      print_usage
      exit 1
      ;;
    * )
      echo "Unexpected argument: $1"
      print_usage
      exit 1
      ;;
  esac
  shift
done

RELEASE_NAME="kubex-automation-controller"

if [ "${DELETE_MODE}" = true ]; then
  echo "===== Uninstalling ${RELEASE_NAME} helm package ====="
  echo "Uninstalling ${RELEASE_NAME} Helm release..."
  helm uninstall "${RELEASE_NAME}" -n "${NAMESPACE}" || echo "${RELEASE_NAME} release not found."
  
  echo ""
  echo "Note: If the kubex-automation-tls secret was created outside of Helm"
  echo "(e.g., BYOC, cert-manager, or previous installation), it will not be"
  echo "automatically deleted. You may need to remove it manually before reinstalling:"
  echo "  kubectl delete secret kubex-automation-tls -n ${NAMESPACE}"
  echo ""
  
  echo "Uninstallation complete."
  exit 0
fi


# INSTALLATION MODE
echo "===== Installation Mode Activated ====="


# Validate values files exist
if [ "${OPENSHIFT_MODE}" = true ]; then
  if [ ! -f "kubex-automation-values.yaml" ] || [ ! -f "values-openshift.yaml" ]; then
    echo "Error: kubex-automation-values.yaml and/or values-openshift.yaml not found in the current directory: `pwd`"
    exit 1
  fi
else
  if [ ! -f "kubex-automation-values.yaml" ]; then
    echo "Error: kubex-automation-values.yaml not found in the current directory: `pwd`"
    exit 1
  fi
fi

if [ "${CERT_MANAGER_ACTION}" = true ]; then
  echo "Verifying cert-manager is installed..."
  if helm status cert-manager -n cert-manager >/dev/null 2>&1 || \
     kubectl get crd certificates.cert-manager.io >/dev/null 2>&1; then
    echo "cert-manager detected. Will use cert-manager for certificate management."
  else
    echo "ERROR: --certmanager flag specified but cert-manager is not installed."
    echo "Please install cert-manager first or remove the --certmanager flag to use self-signed certificates."
    echo ""
    echo "To install cert-manager, run:"
    echo "  helm repo add jetstack https://charts.jetstack.io"
    echo "  helm repo update"
    echo "  helm install cert-manager jetstack/cert-manager \\"
    echo "    --namespace cert-manager \\"
    echo "    --create-namespace \\"
    echo "    --set crds.enabled=true"
    exit 1
  fi
else
  echo "Using self-signed certificates (10-year validity)."
fi

echo "Installing ${RELEASE_NAME}"

helm repo add kubex https://densify-dev.github.io/helm-charts
helm repo add groundhog2k https://groundhog2k.github.io/helm-charts
helm repo update


if [ "${OPENSHIFT_MODE}" = true ]; then
  echo "OpenShift mode enabled: using values-openshift.yaml for OpenShift compatibility."
  helm upgrade --install "${RELEASE_NAME}" "kubex/${RELEASE_NAME}" \
    -n "${NAMESPACE}" --create-namespace \
    -f kubex-automation-values.yaml \
    -f values-openshift.yaml
else
  helm upgrade --install "${RELEASE_NAME}" "kubex/${RELEASE_NAME}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    -f "./kubex-automation-values.yaml" \
    --set certmanager.enabled="${CERT_MANAGER_ACTION}"
fi

echo "Installation complete in namespace: ${NAMESPACE}"

# Check if createSecrets is set to false and warn
CREATE_SECRETS=$(grep -E "^createSecrets:" kubex-automation-values.yaml | awk '{print $2}')
if [ "${CREATE_SECRETS}" = "false" ]; then
  echo ""
  echo "⚠️  ========================================"
  echo "⚠️  IMPORTANT: createSecrets is set to false"
  echo "⚠️  ========================================"
  echo ""
  echo "The Helm chart has been deployed, but pods will NOT start until you:"
  echo ""
  echo "1. Create the following secrets in your external secret management system:"
  echo "   - kubex-api-secret-container-automation (Kubex API credentials)"
  echo "   - kubex-valkey-client-auth (Valkey client authentication)"
  echo "   - kubex-valkey-secret (Valkey server configuration)"
  echo "   - kubex-automation-tls (TLS certificate - use cert-manager or BYOC)"
  echo ""
  echo "2. Sync the secrets to the 'kubex' namespace using your secret management tool"
  echo "   (e.g., External Secrets Operator, Sealed Secrets, etc.)"
  echo ""
  echo "3. Verify secrets exist:"
  echo "   kubectl get secrets -n kubex"
  echo ""
  echo "4. Once secrets are created, pods will automatically start."
  echo "   If pods don't start automatically, restart them:"
  echo "   kubectl rollout restart deployment -n kubex"
  echo ""
  echo "For detailed instructions, see:"
  echo "  docs/Configuration-Reference.md#secret-management-configuration"
  echo "  docs/Configuration-Reference.md#tls-certificate-secret-external-secret-management"
  echo ""
fi
