#!/bin/bash

# This is a utility script to clean up all the GCP service account
# and all of its roles.
# Use with care, only if required!

export PROJECT_ID=$(gcloud config get-value project)
export GSA_NAME="kubex-forwarder"
export GSA_EMAIL="${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# 1. Remove roles granted TO the service account (Project Level)
#    (Prevents "deleted:serviceAccount:..." clutter in your project policy)
for role in $(gcloud projects get-iam-policy ${PROJECT_ID} \
  --flatten="bindings[].members" \
  --format="value(bindings.role)" \
  --filter="bindings.members:serviceAccount:${GSA_EMAIL}"); do
  
  echo "Revoking ${role} from project..."
  gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="${role}" --quiet
done

# 2. Delete the Service Account
#    (Automatically destroys any bindings attached ON the account)
echo "Deleting service account..."
gcloud iam service-accounts delete ${GSA_EMAIL} --project=${PROJECT_ID} --quiet

echo "Done. Account and all policies cleanly removed."
