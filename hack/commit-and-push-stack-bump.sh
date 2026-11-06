#!/usr/bin/env bash
# Commits the staged dependency bump and force-pushes it to the stable
# sync/kubex-automation-stack branch (reused across runs, not per-commit),
# using the GitHub App's bot identity.
#
# Env vars:
#   APP_SLUG      - required, e.g. "kubexautomation"
#   BOT_USER_ID   - required, numeric user id (from get-app-bot-user-id.sh)
#   APP_TOKEN     - required, the minted installation token (used for push auth)
#   GITHUB_REPOSITORY - required, "owner/repo" (set by the Actions runner)
#   GITHUB_OUTPUT - required (set by the Actions runner)
#
# Outputs (via $GITHUB_OUTPUT):
#   branch - the pushed branch name
set -euo pipefail

: "${APP_SLUG:?APP_SLUG must be set}"
: "${BOT_USER_ID:?BOT_USER_ID must be set}"
: "${APP_TOKEN:?APP_TOKEN must be set}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY must be set}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"

git config user.name "${APP_SLUG}[bot]"
git config user.email "${BOT_USER_ID}+${APP_SLUG}[bot]@users.noreply.github.com"

short_sha="$(git rev-parse --short HEAD)"
branch_name="sync/kubex-automation-stack"
git checkout -B "${branch_name}"
git commit -m "Update kubex-automation-stack dependencies (${short_sha})"
git remote set-url origin "https://x-access-token:${APP_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
git push --force origin "HEAD:${branch_name}"
echo "branch=${branch_name}" >> "$GITHUB_OUTPUT"
