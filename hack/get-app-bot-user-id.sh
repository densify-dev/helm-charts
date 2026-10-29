#!/usr/bin/env bash
# Resolves the numeric GitHub user id for a GitHub App's bot identity
# (e.g. "kubexautomation[bot]"), needed to construct its noreply commit
# email address.
#
# Env vars:
#   APP_SLUG      - required, e.g. "kubexautomation"
#   GH_TOKEN      - required, a token with read access to the users API
#   GITHUB_OUTPUT - required (set by the Actions runner)
#
# Outputs (via $GITHUB_OUTPUT):
#   id - the bot's numeric user id
set -euo pipefail

: "${APP_SLUG:?APP_SLUG must be set}"
: "${GH_TOKEN:?GH_TOKEN must be set}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"

id="$(gh api "/users/${APP_SLUG}[bot]" --jq .id)"
echo "id=${id}" >> "$GITHUB_OUTPUT"
