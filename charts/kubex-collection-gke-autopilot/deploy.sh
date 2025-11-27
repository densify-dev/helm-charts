#!/bin/bash
# Check args
usage() {
  echo "Usage: ${0} -g <GKE_CLUSTER_NAME> -r <GCP_REGION> [-k <KUBEX_CLUSTER_NAME>] [-a <ARCH>] [-n] [-h]" >&2
  echo "  or:"
  echo "       ${0} -g <GKE_CLUSTER_NAME> -z <GCP_ZONE> [-k <KUBEX_CLUSTER_NAME>] [-a <ARCH>] [-n] [-h]" >&2
  echo "     -g <GKE_CLUSTER_NAME> (required)"
  echo "     -r <GCP_REGION>*"
  echo "     -z <GCP_ZONE>*"
  echo "        * exactly ONE of GCP_REGION or GCP_ZONE is required, but NOT both"
  echo "     -k <KUBEX_CLUSTER_NAME> (optional, default: same as GKE_CLUSTER_NAME)"
  echo "     -a <ARCH> (optional, default: amd64)"
  echo "     -n (optional, use ONLY if you want to deploy Kubex data collection"
  echo "        on a non-GKE and collect data from Google Managed Prometheus for"
  echo "        a GKE cluster)"
  echo "     -h (optional, print this help and exit)"
  exit ${1}
}

GKE_CLUSTER_NAME=""
KUBEX_CLUSTER_NAME=""
GCP_REGION=
GCP_ZONE=
GCP_LOCATION=
export RUN_IN_GKE_AUTOPILOT="true"
export TARGET_ARCH="amd64"

while getopts ":g:r:z:k:a:nh" opt; do
  case "${opt}" in
    g) export GKE_CLUSTER_NAME="${OPTARG}" ;;
    r) export GCP_REGION="${OPTARG}" ;;
    z) export GCP_ZONE="${OPTARG}" ;;
    k) export KUBEX_CLUSTER_NAME="${OPTARG}" ;;
    a) export TARGET_ARCH="${OPTARG}" ;;
    n) export RUN_IN_GKE_AUTOPILOT="false" ;;
    h) usage 0 ;;
    *) usage 1 ;;
  esac
done

# Check required flag
if [[ -z "${GKE_CLUSTER_NAME}" ]]; then
  echo "Missing required flag: -g <GKE_CLUSTER_NAME>" >&2
  usage 1
fi

if [[ -n "${GCP_REGION}" ]]; then
  if [[ -n "${GCP_ZONE}" ]]; then
    echo "Error: You cannot specify both a GCP_REGION (-r) and a GCP_ZONE (-z)" >&2
    usage 1
  else
    export GCP_LOCATION="--region ${GCP_REGION}"
  fi
else
  if [[ -n "${GCP_ZONE}" ]]; then
    export GCP_LOCATION="--zone ${GCP_ZONE}"
  else
    echo "Error: You must provide either a GCP_REGION (-r) or a GCP_ZONE (-z)." >&2
    usage 1
  fi
fi

# Optional kubex_cluster_name: default to gke_cluster_name if not provided
if [[ -z "${KUBEX_CLUSTER_NAME}" ]]; then
  export KUBEX_CLUSTER_NAME="${GKE_CLUSTER_NAME}"
  echo "KUBEX_CLUSTER_NAME not provided; using GKE_CLUSTER_NAME value: '${KUBEX_CLUSTER_NAME}'"
fi

# Export Variables
export PROJECT_ID=$(gcloud config get-value project)
export HOST_PROJECT_NUMBER=$(gcloud beta monitoring metrics-scopes list projects/${PROJECT_ID} | grep 'name:' | rev | cut -d'/' -f1 | rev)
export HOST_PROJECT=$(gcloud projects describe ${HOST_PROJECT_NUMBER} --format="value(projectId)")
export K8S_NAMESPACE="kubex"
export SA_NAME="kubex-forwarder"
export GSA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
export GSA_KEY_NAME=${SA_NAME}-key.json
export GKE_AUTOPILOT_VALUES=values-gke-autopilot.yaml

# Define the Infinite Retry Function
function run_until_success() {
  echo "Running: $@ ..."
  
  # 'until' runs the command. If it fails (non-zero exit code), it runs the loop body.
  # If it succeeds (exit code 0), it skips the loop and moves on.
  until "$@" > /dev/null 2>&1; do
    echo "   ⏳ Waiting for propagation... (retrying in 5s)"
    sleep 5
  done
  
  echo "   ✅ Success!"
}

function gmpTestCmd() {
  gcloud container clusters describe ${GKE_CLUSTER_NAME} ${GCP_LOCATION} --format="value(monitoringConfig.managedPrometheusConfig.enabled)" | grep -i -q true
}

# Check if GKE cluster exists
if ! gcloud container clusters list --format="value(name)" | grep -q -x "${GKE_CLUSTER_NAME}"; then
  echo "GKE cluster ${GKE_CLUSTER_NAME} does not exist, exiting"
  exit 2
fi

# verify that Managed Prometheus is enabled for the cluster
if ! gmpTestCmd; then
  echo "GMP not enabled for cluster ${GKE_CLUSTER_NAME}"
  echo "Enabling GMP - this may take a while..."
  gcloud container clusters update ${GKE_CLUSTER_NAME} ${GCP_LOCATION} --enable-managed-prometheus
  run_until_success gmpTestCmd
  echo "Making sure Google Monitoring CRDs are available"
  for CRD in clusternodemonitoring clusterpodmonitoring; do
    if ! kubectl wait --for condition=established --timeout=300s \
      crd/${CRD}s.monitoring.googleapis.com; then
        echo "Google Monitoring CRD ${CRD} not available"
        exit 3
    fi
  done
fi

rm -f ${GKE_AUTOPILOT_VALUES}

if [[ "${RUN_IN_GKE_AUTOPILOT}" != "true" ]]; then
cat <<EOF > ${GKE_AUTOPILOT_VALUES}
stack:
  runsInGKEAutopilot: false
EOF
fi
cat <<EOF >> ${GKE_AUTOPILOT_VALUES}
container-optimization-data-forwarder:
  config:
    prometheus:
      url:
        scheme: https
        host: 'monitoring.googleapis.com/v1/projects/${HOST_PROJECT}/location/global/prometheus'
        port: 443
EOF
if [[ "${RUN_IN_GKE_AUTOPILOT}" != "true" ]]; then
cat <<EOF >> ${GKE_AUTOPILOT_VALUES}
      GoogleMonitoringSecretName: 'gcp-service-account-secret'
      GoogleMonitoringKeyName: '${GSA_KEY_NAME}'
EOF
fi
cat <<EOF >> ${GKE_AUTOPILOT_VALUES}
    clusters:
      - name: '${KUBEX_CLUSTER_NAME}' # mandatory, this is how the cluster name will appear in Kubex, must be unique
        identifiers:
          cluster: '${GKE_CLUSTER_NAME}' # mandatory, GKE Autopilot cluster name as it appears in Google Cloud console
          collected_by: 'kubex-stack' # mandatory, DO NOT remove this label
EOF
if [[ "${RUN_IN_GKE_AUTOPILOT}" == "true" ]]; then
cat <<EOF >> ${GKE_AUTOPILOT_VALUES}
  serviceAccount:
    isGKE: true
    create: true
    name: '${SA_NAME}'
    annotations:
      iam.gke.io/gcp-service-account: '${GSA_EMAIL}'
EOF
fi

export SERVICE_ACCOUNT_EXISTS="false"
# Check if Service Account exists
if gcloud iam service-accounts describe "${GSA_EMAIL}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
  echo "Service Account ${GSA_EMAIL} already exists, skipping creation and policy bindings."
  export SERVICE_ACCOUNT_EXISTS="true"
fi

if [[ "${SERVICE_ACCOUNT_EXISTS}" != "true" ]]; then
  # Create Service Account
  echo "Creating Service Account..."
  gcloud iam service-accounts create ${SA_NAME} \
    --project=${PROJECT_ID} \
    --display-name="Kubex Forwarder"

  # Apply Project Binding (Infinite Retry)
  echo "Step 1/2: Binding Role to Project..."
  run_until_success gcloud projects add-iam-policy-binding ${HOST_PROJECT} \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/monitoring.viewer"

  # Apply Service Account Binding (Infinite Retry)
  echo "Step 2/2: Binding Workload Identity User..."
  run_until_success gcloud iam service-accounts add-iam-policy-binding \
    "${GSA_EMAIL}" \
    --role="roles/iam.workloadIdentityUser" \
    --member="serviceAccount:${PROJECT_ID}.svc.id.goog[${K8S_NAMESPACE}/${SA_NAME}]"
fi

export HELM_RELEASE="kubex"
export HELM_EXTRA_ARGS=
if [[ "${RUN_IN_GKE_AUTOPILOT}" != "true" ]]; then
  # Create Key (Conditional & Infinite Retry)
  echo "Optional step 3/3: Creating JSON Key..."
  
  # Safety: Remove existing key file so 'gcloud' doesn't error out locally
  # saying "file exists", which would cause an infinite loop.
  rm -f "${GSA_KEY_NAME}"

  run_until_success gcloud iam service-accounts keys create ${GSA_KEY_NAME} \
    --iam-account=${GSA_EMAIL}

  export HELM_EXTRA_ARGS="--set stack.gcpServiceAccountKeyName=${GSA_KEY_NAME} --set-file stack.gcpServiceAccountKeyContents=${GSA_KEY_NAME}"
fi

if [[ "${TARGET_ARCH}" == "arm64" ]]; then
  export HELM_EXTRA_ARGS="${HELM_EXTRA_ARGS} -f values-arm64.yaml"
fi

helm upgrade --install --create-namespace -n ${K8S_NAMESPACE} -f ${GKE_AUTOPILOT_VALUES} -f values-edit.yaml ${HELM_EXTRA_ARGS} ${HELM_RELEASE} densify/kubex-collection-gke-autopilot
