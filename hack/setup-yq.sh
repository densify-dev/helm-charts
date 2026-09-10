#!/usr/bin/env bash
# Installs a pinned, checksum-verified yq (mikefarah/yq) binary into
# $RUNNER_TEMP and puts it on PATH for subsequent steps (avoids requiring
# write access to /usr/local/bin).
#
# YQ_LINUX_AMD64_SHA256 must be updated together with YQ_VERSION whenever
# the pinned version changes. To compute it for a new version:
#   curl -sL "https://github.com/mikefarah/yq/releases/download/<version>/yq_linux_amd64" | sha256sum
#
# Env vars:
#   YQ_VERSION  - required, e.g. "v4.47.1"
#   RUNNER_TEMP - required (set by the Actions runner)
#   GITHUB_PATH - required (set by the Actions runner)
set -euo pipefail

: "${YQ_VERSION:?YQ_VERSION must be set}"
: "${RUNNER_TEMP:?RUNNER_TEMP must be set}"
: "${GITHUB_PATH:?GITHUB_PATH must be set}"

YQ_LINUX_AMD64_SHA256="0fb28c6680193c41b364193d0c0fc4a03177aecde51cfc04d506b1517158c2fb"

curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" -o "${RUNNER_TEMP}/yq"
echo "${YQ_LINUX_AMD64_SHA256}  ${RUNNER_TEMP}/yq" | sha256sum -c -
chmod +x "${RUNNER_TEMP}/yq"
echo "${RUNNER_TEMP}" >> "$GITHUB_PATH"
"${RUNNER_TEMP}/yq" --version
