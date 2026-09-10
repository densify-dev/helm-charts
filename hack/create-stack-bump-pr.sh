#!/usr/bin/env bash
# Creates the stack dependency bump PR, or updates it in place if one is
# already open for this branch.
#
# Env vars:
#   BRANCH             - required, the pushed branch name
#   NEXT_STACK_VERSION - required, the new stack chart version
#   CHANGELOG_BULLETS  - required, "- Updated ..." lines (from detect step)
#   GH_TOKEN           - required, token with pull-request write access
#   GITHUB_REPOSITORY  - required, "owner/repo" (set by the Actions runner)
set -euo pipefail

: "${BRANCH:?BRANCH must be set}"
: "${NEXT_STACK_VERSION:?NEXT_STACK_VERSION must be set}"
: "${CHANGELOG_BULLETS:?CHANGELOG_BULLETS must be set}"
: "${GH_TOKEN:?GH_TOKEN must be set}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY must be set}"

title="Update kubex-automation-stack dependencies"
body_file="$(mktemp)"
{
  echo "This PR was created automatically after Release Charts published a new version of one or more subcharts used by kubex-automation-stack."
  echo
  echo "Changes:"
  printf '%s' "${CHANGELOG_BULLETS}"
  echo "- Regenerated Chart.lock"
  echo "- Bumped kubex-automation-stack to ${NEXT_STACK_VERSION}"
} > "${body_file}"

existing="$(gh pr list --repo "${GITHUB_REPOSITORY}" --head "${BRANCH}" --state open --json number --jq '.[0].number // empty')"
if [[ -n "${existing}" ]]; then
  gh pr edit "${existing}" --repo "${GITHUB_REPOSITORY}" --title "${title}" --body-file "${body_file}"
  echo "updated PR #${existing}"
else
  gh pr create --repo "${GITHUB_REPOSITORY}" --base master --head "${BRANCH}" --title "${title}" --body-file "${body_file}"
fi
