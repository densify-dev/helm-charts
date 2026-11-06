#!/usr/bin/env bash
# Adds and updates the Helm repos needed to resolve kubex-automation-stack's
# dependencies (both self-published and external).
set -euo pipefail

helm repo add kubex https://densify-dev.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
