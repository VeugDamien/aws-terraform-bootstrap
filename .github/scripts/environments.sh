#!/usr/bin/env bash
# Prints the environments to run as a JSON array, for a GitHub Actions matrix.
#
# An environment is a folder environments/<name>/ that contains a ci.json.
#   environments.sh             -> every environment
#   environments.sh BASE HEAD   -> only the environments affected by BASE..HEAD:
#     - a change under environments/<name>/ affects <name> only;
#     - a change under modules/, .github/ or .terraform-version affects all;
#     - other changes (README, bootstrap/...) affect none.
set -euo pipefail

all="$(find environments -mindepth 2 -maxdepth 2 -name ci.json 2>/dev/null \
  | awk -F/ '{print $2}' | sort -u)"

# Folder names become GitHub Environment names and paths: keep them simple.
while IFS= read -r env; do
  [[ -z "${env}" || "${env}" =~ ^[a-z0-9][a-z0-9-]{0,30}$ ]] \
    || { echo "Invalid environment folder name: ${env} (use a-z, 0-9 and -)" >&2; exit 1; }
done <<<"${all}"

selected="${all}"
base="${1:-}" head="${2:-}"
# Without a usable base (first push, manual run), run every environment.
if [[ -n "${base}" && ! "${base}" =~ ^0+$ ]] && git cat-file -e "${base}^{commit}" 2>/dev/null; then
  changed="$(git diff --name-only "${base}" "${head}")"
  if grep -qE '^(modules/|\.github/|\.terraform-version$)' <<<"${changed}"; then
    selected="${all}"
  else
    touched="$(grep '^environments/' <<<"${changed}" | awk -F/ '{print $2}' | sort -u || true)"
    selected="$(grep -Fx -f <(printf '%s\n' "${touched}") <<<"${all}" || true)"
  fi
fi

grep -v '^$' <<<"${selected}" | jq -R . | jq -cs .
