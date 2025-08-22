#!/bin/bash

set -e

print_usage() {
  echo "Usage:"
  echo "  ./deploy-kubex-automation-controller.sh [--certmanager] [--delete]"
  echo
  echo "Options:"
  echo "  --certmanager       Include this flag if you intend to use cert-manager."
  echo "                      If cert-manager is not already installed, it will be installed."
  echo "                      If used with --delete, cert-manager and its resources will be deleted."
  echo
  echo "  --delete            Uninstalls the kubex-automation-controller Helm release."
  echo "                      If --certmanager is also specified, cert-manager and its resources will be removed."
  echo
}


# Default values
NAMESPACE="densify"
CERT_MANAGER_ACTION=false
DELETE_MODE=false

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --certmanager)
      CERT_MANAGER_ACTION=true
      ;;
    --delete)
      DELETE_MODE=true
      ;;
    -*)
      echo "Unknown parameter passed: $1"
      print_usage
      exit 1
      ;;
    *)
      echo "Unexpected argument: $1"
      print_usage
      exit 1
      ;;
  esac
  shift
done

RELEASE_NAME="kubex-automation-controller"

if [ "${DELETE_MODE}" = true ]; then
  echo "===== Deleting Densify kubex-automation-controller helm package ====="
  echo "Deleting kubex-automation-controller Helm release..."
  helm uninstall "${RELEASE_NAME}" -n "${NAMESPACE}" || echo "kubex-automation-controller release not found."

  if [ "${CERT_MANAGER_ACTION}" = true ]; then
    echo "===== Deleting cert-manager resources ====="
    echo "Uninstalling cert-manager Helm release..."
    helm uninstall cert-manager -n cert-manager || echo "cert-manager release not found."

    echo "Deleting cert-manager Custom Resource Definitions (CRDs)..."
    kubectl delete crd \
    issuers.cert-manager.io \
    clusterissuers.cert-manager.io \
    certificates.cert-manager.io \
    certificaterequests.cert-manager.io \
    orders.acme.cert-manager.io \
    challenges.acme.cert-manager.io

    echo "Deleting cert-manager namespace..."
    kubectl delete namespace cert-manager || echo "Namespace cert-manager not found."
  else
    echo "Skipping cert-manager deletion."
  fi

  echo "Deletion complete."
  exit 0
fi


# INSTALLATION MODE
echo "===== Installation Mode Activated ====="
echo "Install Cert-Manager: ${CERT_MANAGER_ACTION}"


# Validate values-edit.yaml exists
if [ ! -f "values-edit.yaml" ]; then
  echo "Error: values-edit.yaml not found in the current directory: `pwd`"
  exit 1
fi

if [ "${CERT_MANAGER_ACTION}" = true ]; then
  if helm status cert-manager -n cert-manager >/dev/null 2>&1 || \
     kubectl get crd certificates.cert-manager.io >/dev/null 2>&1; then
    echo "cert-manager is already installed (via Helm or kubectl). Skipping installation."
  else
    echo "cert-manager not detected. Proceeding with Helm install."
    echo "Adding Jetstack Helm repo for cert-manager..."
    helm repo add jetstack https://charts.jetstack.io --force-update

    echo "Installing cert-manager..."
    helm upgrade --install cert-manager jetstack/cert-manager \
      --namespace cert-manager \
      --create-namespace \
      --version v1.18.2 \
      --set crds.enabled=true

    for deploy in cert-manager cert-manager-webhook cert-manager-cainjector; do
      echo "Waiting for deployment/$deploy rollout..."
      kubectl rollout status deployment/$deploy -n cert-manager --timeout=120s || {
        echo "Rollout failed for $deploy"
        exit 1
      }
    done
  fi
else
  echo "Skipping cert-manager installation."
fi

echo "Installing ${RELEASE_NAME}"
kubectl get namespace "${NAMESPACE}" || kubectl create namespace "${NAMESPACE}"

helm repo add densify https://densify-dev.github.io/helm-charts
helm repo update

helm upgrade --install "${RELEASE_NAME}" "densify/${RELEASE_NAME}" \
  --namespace "${NAMESPACE}" \
  -f "./values-edit.yaml" \
  --set certmanager.enabled="${CERT_MANAGER_ACTION}"

echo "Installation complete in namespace: ${NAMESPACE}"
