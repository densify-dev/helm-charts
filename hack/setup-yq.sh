#!/usr/bin/env bash
# Installs a pinned yq (mikefarah/yq) binary into $RUNNER_TEMP and puts it on
# PATH for subsequent steps (avoids requiring write access to /usr/local/bin).
#
# Env vars:
#   YQ_VERSION  - required, e.g. "v4.47.1"
#   RUNNER_TEMP - required (set by the Actions runner)
#   GITHUB_PATH - required (set by the Actions runner)
set -euo pipefail

: "${YQ_VERSION:?YQ_VERSION must be set}"
: "${RUNNER_TEMP:?RUNNER_TEMP must be set}"
: "${GITHUB_PATH:?GITHUB_PATH must be set}"

curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" -o "${RUNNER_TEMP}/yq"
chmod +x "${RUNNER_TEMP}/yq"
echo "${RUNNER_TEMP}" >> "$GITHUB_PATH"
"${RUNNER_TEMP}/yq" --version
