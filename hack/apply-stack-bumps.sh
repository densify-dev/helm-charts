#!/usr/bin/env bash
# Applies the dependency bumps detected by detect-stack-bumps.sh: updates
# Chart.yaml, patch-bumps the stack chart itself, regenerates Chart.lock,
# lints, inserts a CHANGELOG.md entry, and verifies only the expected
# three files changed.
#
# Env vars:
#   STACK_CHART_DIR    - required, path to the stack chart directory
#   BUMP_LIST          - required, "<name>=<version>" lines (from detect step)
#   CHANGELOG_BULLETS  - required, "- Updated ..." lines (from detect step)
#   GITHUB_OUTPUT      - required (set by the Actions runner)
#
# Outputs (via $GITHUB_OUTPUT):
#   next_stack_version - the new kubex-automation-stack chart version
set -euo pipefail

: "${STACK_CHART_DIR:?STACK_CHART_DIR must be set}"
: "${BUMP_LIST:?BUMP_LIST must be set}"
: "${CHANGELOG_BULLETS:?CHANGELOG_BULLETS must be set}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"

chart_file="${STACK_CHART_DIR}/Chart.yaml"

while IFS='=' read -r name version; do
  [[ -z "${name}" ]] && continue
  yq eval -i "(.dependencies[] | select(.name == \"${name}\") | .version) = \"${version}\"" "${chart_file}"
done <<< "${BUMP_LIST}"

current_stack_version="$(yq eval '.version' "${chart_file}")"
if [[ ! "${current_stack_version}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "::error::unexpected stack chart version format: ${current_stack_version}"
  exit 1
fi
major="${BASH_REMATCH[1]}"; minor="${BASH_REMATCH[2]}"; patch="${BASH_REMATCH[3]}"
next_stack_version="${major}.${minor}.$((patch + 1))"
yq eval -i ".version = \"${next_stack_version}\"" "${chart_file}"
echo "next_stack_version=${next_stack_version}" >> "$GITHUB_OUTPUT"

# Publishing a new chart version ships everything currently on master,
# including whatever is staged under "## [Unversioned changes]" — if that
# section has real content, it would ship silently mislabeled as
# unversioned under the new release. Fail loudly instead of guessing how
# to merge it; a human needs to promote or clear it first.
unversioned_content="$(awk '
  /^## \[Unversioned changes\]/ { capture = 1; next }
  capture && /^## \[/ { exit }
  capture && /^---/ { exit }
  capture && /^###/ { next }
  capture && NF > 0 { print }
' "${STACK_CHART_DIR}/CHANGELOG.md")"
if [[ -n "${unversioned_content}" ]]; then
  echo "::error::CHANGELOG.md has non-empty '## [Unversioned changes]' content, which would ship under the new version ${next_stack_version} while still being labeled unversioned. Promote or clear it manually before this workflow can run:" >&2
  echo "${unversioned_content}" >&2
  exit 1
fi

helm dependency update "${STACK_CHART_DIR}"
helm lint "${STACK_CHART_DIR}" -f "${STACK_CHART_DIR}/values-edit.yaml"

changelog_date="$(date -u +%F)"
entry_file="$(mktemp)"
{
  echo "## [${next_stack_version}] - ${changelog_date}"
  echo
  echo "### Changed"
  printf '%s' "${CHANGELOG_BULLETS}"
  echo
  echo "---"
  echo
} > "${entry_file}"

awk -v entryfile="${entry_file}" '
  BEGIN { while ((getline line < entryfile) > 0) entry = entry line "\n"; inserted = 0 }
  /^## \[[0-9]/ && !inserted { printf "%s", entry; inserted = 1 }
  { print }
  END { if (!inserted) { print "ERROR: no versioned changelog entry found" > "/dev/stderr"; exit 1 } }
' "${STACK_CHART_DIR}/CHANGELOG.md" > "${STACK_CHART_DIR}/CHANGELOG.md.new"
mv "${STACK_CHART_DIR}/CHANGELOG.md.new" "${STACK_CHART_DIR}/CHANGELOG.md"

git add "${STACK_CHART_DIR}/Chart.yaml" "${STACK_CHART_DIR}/Chart.lock" "${STACK_CHART_DIR}/CHANGELOG.md"
changed="$(git diff --cached --name-only | sort | tr '\n' ' ')"
expected="${STACK_CHART_DIR}/CHANGELOG.md ${STACK_CHART_DIR}/Chart.lock ${STACK_CHART_DIR}/Chart.yaml "
if [[ "${changed}" != "${expected}" ]]; then
  echo "::error::unexpected file set staged: ${changed}"
  exit 1
fi
