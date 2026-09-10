#!/usr/bin/env bash
# Installs a pinned yq (mikefarah/yq) binary to /usr/local/bin.
#
# Env vars:
#   YQ_VERSION - required, e.g. "v4.47.1"
set -euo pipefail

: "${YQ_VERSION:?YQ_VERSION must be set}"

curl -sL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" -o /usr/local/bin/yq
chmod +x /usr/local/bin/yq
yq --version
