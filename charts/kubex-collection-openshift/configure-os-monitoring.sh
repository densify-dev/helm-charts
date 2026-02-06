#!/bin/bash

# Configuration variables
NAMESPACE="openshift-monitoring"
CM_NAME="cluster-monitoring-config"
CONFIG_KEY="config.yaml"
TMP_DIR=$(mktemp -d)

# Cleanup temporary files on exit
trap "rm -rf ${TMP_DIR}" EXIT

echo "--- Checking OpenShift Cluster Monitoring Configuration ---"

# 1. Search for the ConfigMap
if ! oc get cm "${CM_NAME}" -n "${NAMESPACE}" &> /dev/null; then
    # ---------------------------------------------------------
    # CASE: ConfigMap NOT FOUND -> Create it
    # ---------------------------------------------------------
    echo "ConfigMap '${CM_NAME}' not found in namespace '${NAMESPACE}'."
    echo "Creating ConfigMap..."
    FILE="${TMP_DIR}/${CM_NAME}.yaml"
    cat <<EOF > ${FILE}
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${CM_NAME}
  namespace: ${NAMESPACE}
data:
  config.yaml: |
    enableUserWorkload: true
EOF
    oc apply -f ${FILE}
else
    # ---------------------------------------------------------
    # CASE: ConfigMap FOUND -> Check and Update
    # ---------------------------------------------------------
    UPDATE_NEEDED=false
    FILE="${TMP_DIR}/${CONFIG_KEY}"
    echo "ConfigMap '${CM_NAME}' found. Analyzing '${CONFIG_KEY}'..."

    # Extract the current 'config.yaml' content to a temporary file
    # We use jsonpath to extract strictly the value of the key
    oc get cm "${CM_NAME}" -n "${NAMESPACE}" -o jsonpath="{.data['config\.yaml']}" > "${TMP_DIR}/${CONFIG_KEY}"

    # Check if the file is empty (key existed but was empty, or key didn't exist in data)
    if [ ! -s "${FILE}" ]; then
        echo "Data key is empty. Setting value."
        echo "enableUserWorkload: true" > "${FILE}"
        UPDATE_NEEDED=true
    else
        # Check if enableUserWorkload is explicitly set to false
        # We look for "enableUserWorkload:" followed optionally by space, then "false"
        if grep -qE "^\s*enableUserWorkload:\s*false" "${FILE}"; then
            echo "Found 'enableUserWorkload: false'. Updating to 'true'..."
            
            # Use sed to replace false with true, preserving indentation if any
            # We use a temp file for sed to ensure compatibility between Linux (GNU) and macOS (BSD)
            sed 's/\(^\s*enableUserWorkload:\s*\)false/\1true/' "${FILE}" > "${FILE}.tmp" && mv "${FILE}.tmp" "${FILE}"
            UPDATE_NEEDED=true

        # Check if enableUserWorkload is already set to true
        elif grep -qE "^\s*enableUserWorkload:\s*true" "${FILE}"; then
            echo "✅ 'enableUserWorkload: true' is already set. No changes required."
            UPDATE_NEEDED=false

        # If it is not found at all, append it
        else
            echo "'enableUserWorkload' setting missing. Appending to config..."
            # Add a newline just in case the file doesn't end with one, then the setting
            echo "" >> "${FILE}"
            echo "enableUserWorkload: true" >> "${FILE}"
            UPDATE_NEEDED=true
        fi
    fi
    # Apply changes if needed
    if [ "${UPDATE_NEEDED}" = true ]; then
        # We use 'oc set data' to update ONLY this specific key, 
        # ensuring we don't accidentally wipe other keys in the ConfigMap.
        oc set data cm/"${CM_NAME}" -n "${NAMESPACE}" --from-file="${CONFIG_KEY}=${FILE}"
        echo "✅ Configuration updated successfully."
    fi
fi
