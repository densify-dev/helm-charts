#!/usr/bin/env bash
# Run after helm dependency build charts/kubex-automation-controller.
set -euo pipefail
cd "$(dirname "$0")/.."
chart=charts/kubex-automation-controller
helm=${HELM:-helm}
[[ $($helm version --short) == v3.* ]] || { echo 'Helm 3 is required' >&2; exit 1; }
out=$(mktemp)
trap 'rm -f "$out"' EXIT
for platform in default openshift; do
  args=()
  [[ $platform != openshift ]] || args+=(-f "$chart/values-openshift.yaml")
  for images in defaults legacy; do
    overrides=()
    director=densify/automation-director:1.5
    gateway=densify/automation-gateway:1.11
    if [[ $images == legacy ]]; then
      director=example.invalid/director:legacy
      gateway=example.invalid/gateway:legacy
      overrides+=(--set-string "deployment.controllerImage=$director,deployment.gatewayImage=$gateway")
    fi
    "$helm" template release-test "$chart" -f "$chart/kubex-automation-values.yaml" \
      --set-string 'densify.url.host=example.invalid,densifyCredentials.username=test,densifyCredentials.epassword=test,valkey.credentials.password=test-only,cluster.name=render-test' \
      --show-only templates/deployment.yaml "${args[@]}" "${overrides[@]}" > "$out"
    [[ $(grep -Fc "image: \"$director\"" "$out") == 1 ]]
    [[ $(grep -Fc "image: \"$gateway\"" "$out") == 2 ]]
    ! grep -q 'allowPrivilegeEscalation: true' "$out"
    grep -q 'readOnlyRootFilesystem: true' "$out"
    grep -q -- '- ALL' "$out"
    if [[ $platform == openshift ]]; then
      ! grep -Eq 'runAsUser:|runAsGroup:|fsGroup:|seccompProfile:' "$out"
    else
      grep -q 'runAsUser: 3000' "$out"
      grep -q 'type: RuntimeDefault' "$out"
    fi
    echo "PASS: $platform / $images"
  done
done
