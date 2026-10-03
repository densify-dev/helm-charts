#!/usr/bin/env bash
# Compares kubex-automation-stack's pinned self-published dependency
# versions against what's actually published, and reports which (if any)
# are out of date.
#
# Reads the published index directly from the gh-pages branch via git
# rather than through the GitHub Pages HTTP endpoint (helm repo
# add/update): Pages serving can lag behind a gh-pages push by some
# seconds, so a lookup through the CDN right after Release Charts
# completes can return a stale index and silently miss a real bump.
# Reading the branch content directly has no such lag.
#
# Env vars:
#   STACK_CHART_DIR     - required, path to the stack chart directory
#   SELF_PUBLISHED_DEPS - required, whitespace-separated dependency names
#   GITHUB_OUTPUT        - required (set by the Actions runner)
#
# Outputs (via $GITHUB_OUTPUT):
#   needs_bump         - "true" or "false"
#   bump_list          - "<name>=<version>" lines, one per out-of-date dep
#   changelog_bullets  - "- Updated <name> dependency to <version>." lines
set -euo pipefail

: "${STACK_CHART_DIR:?STACK_CHART_DIR must be set}"
: "${SELF_PUBLISHED_DEPS:?SELF_PUBLISHED_DEPS must be set}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"

chart_file="${STACK_CHART_DIR}/Chart.yaml"

git fetch origin gh-pages --depth=1 --quiet
index_file="$(mktemp)"
git show origin/gh-pages:index.yaml > "${index_file}"

bump_list=""
summary=""

for name in ${SELF_PUBLISHED_DEPS}; do
  current="$(yq eval "(.dependencies[] | select(.name == \"${name}\")) | .version" "${chart_file}")"
  if [[ -z "${current}" || "${current}" == "null" ]]; then
    echo "::error::${name} is listed in SELF_PUBLISHED_DEPS but is not a dependency of ${chart_file}"
    exit 1
  fi
  latest="$(yq eval ".entries.\"${name}\"[].version" "${index_file}" | sort -V | tail -1)"
  if [[ -z "${latest}" ]]; then
    echo "::error::could not resolve published version for ${name} from gh-pages/index.yaml"
    exit 1
  fi
  if [[ "${current}" != "${latest}" ]]; then
    echo "${name} out of date: ${current} -> ${latest}"
    bump_list="${bump_list}${name}=${latest}"$'\n'
    summary="${summary}- Updated ${name} dependency to ${latest}."$'\n'
  fi
done

if [[ -z "${bump_list}" ]]; then
  echo "needs_bump=false" >> "$GITHUB_OUTPUT"
  echo "no self-published dependency is out of date; nothing to do"
  exit 0
fi

echo "needs_bump=true" >> "$GITHUB_OUTPUT"
{
  echo "bump_list<<EOF_BUMP_LIST"
  printf '%s' "${bump_list}"
  echo "EOF_BUMP_LIST"
  echo "changelog_bullets<<EOF_CHANGELOG"
  printf '%s' "${summary}"
  echo "EOF_CHANGELOG"
} >> "$GITHUB_OUTPUT"
