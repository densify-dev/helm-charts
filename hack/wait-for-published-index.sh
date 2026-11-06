#!/usr/bin/env bash
# Waits until the GitHub Pages Helm repo serves every version in BUMP_LIST.
#
# detect-stack-bumps.sh reads index.yaml from the gh-pages branch, which
# is updated as soon as Release Charts pushes. apply-stack-bumps.sh then
# runs `helm dependency update`, which fetches index.yaml over HTTP from
# GitHub Pages. That copy lags behind the branch until the Pages deploy
# finishes and the CDN cache expires, so resolving a just-published
# version can fail. Poll through Helm itself, the same path `helm
# dependency update` uses, until every bumped version resolves.
#
# Env vars:
#   BUMP_LIST         - required, "<name>=<version>" lines (from detect step)
#   HELM_REPO_NAME    - optional, local Helm repo name (default: kubex)
#   WAIT_TIMEOUT_SECS - optional, give up after this many seconds (default: 900)
#   WAIT_INTERVAL_SECS - optional, seconds between polls (default: 20)
set -euo pipefail

: "${BUMP_LIST:?BUMP_LIST must be set}"
repo="${HELM_REPO_NAME:-kubex}"
timeout_secs="${WAIT_TIMEOUT_SECS:-900}"
interval_secs="${WAIT_INTERVAL_SECS:-20}"

deadline=$((SECONDS + timeout_secs))
while true; do
  helm repo update "${repo}" > /dev/null
  missing=""
  while IFS='=' read -r name version; do
    [[ -z "${name}" ]] && continue
    found="$(helm search repo "${repo}/${name}" --version "${version}" -o json | yq eval 'length' -)"
    if [[ "${found}" == "0" ]]; then
      missing="${missing} ${name}=${version}"
    fi
  done <<< "${BUMP_LIST}"

  if [[ -z "${missing}" ]]; then
    echo "all bumped versions are served by the ${repo} Helm repo"
    exit 0
  fi
  if (( SECONDS >= deadline )); then
    echo "::error::timed out after ${timeout_secs}s waiting for the ${repo} Helm repo to serve:${missing}"
    exit 1
  fi
  echo "not yet served:${missing}; retrying in ${interval_secs}s"
  sleep "${interval_secs}"
done
