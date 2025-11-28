#!/bin/bash

# This is a utility script to clean up all of the user managed keys
# for the service account (GCP has a limit of 10)
# Use with care, only if required!
export PROJECT_ID=$(gcloud config get-value project)
export GSA_NAME="kubex-forwarder"
export GSA_EMAIL="${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Deleting all service account keys..."

# List all keys, filter for user-managed ones, and delete them
gcloud iam service-accounts keys list \
  --iam-account=${GSA_EMAIL} \
  --filter="keyType=USER_MANAGED" \
  --format="value(name)" \
  | xargs -I {} gcloud iam service-accounts keys delete {} \
  --iam-account=${GSA_EMAIL} --quiet
