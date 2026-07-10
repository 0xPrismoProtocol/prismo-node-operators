#!/usr/bin/env bash
# Re-copies the dynamic-glassnet chain files from configs/ into
# deploy/kubernetes/chart/files/, then diffs to confirm they are
# byte-identical.
#
# Why this exists: chart/templates/configmap.yaml embeds these files verbatim
# via `.Files.Get` — Helm can only read files from inside the chart directory,
# so the canonical copies in configs/ (also used by the docker-compose and
# systemd targets) must be mirrored into chart/files/. There is no symlink or
# build step that keeps them in sync automatically; run this script after
# touching any configs/dynamic-glassnet-*.json file, or after a chain reset.
#
# Independent verification: configs/CHECKSUMS.txt carries the sha256 of the
# canonical configs/ copies. After running this script, `sha256sum -c` against
# that file from the chart/files/ directory should also pass, since the copies
# are byte-identical.
#
# Usage: deploy/kubernetes/sync-chart-files.sh [--check]
#   (no args)  copy configs/dynamic-glassnet-*.json -> chart/files/, then diff
#   --check    diff only, do not copy (exits non-zero on drift; CI-friendly)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SRC_DIR="${REPO_ROOT}/configs"
DEST_DIR="${SCRIPT_DIR}/chart/files"

FILES=(
  dynamic-glassnet-allocs.json
  dynamic-glassnet-conf.json
  dynamic-glassnet-chainspec.json
)

CHECK_ONLY=0
if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY=1
fi

mkdir -p "${DEST_DIR}"

status=0
for f in "${FILES[@]}"; do
  src="${SRC_DIR}/${f}"
  dest="${DEST_DIR}/${f}"

  if [[ ! -f "${src}" ]]; then
    echo "ERROR: missing canonical source ${src}" >&2
    status=1
    continue
  fi

  if [[ "${CHECK_ONLY}" -eq 0 ]]; then
    cp "${src}" "${dest}"
  fi

  if [[ ! -f "${dest}" ]]; then
    echo "ERROR: ${dest} does not exist (run without --check to copy)" >&2
    status=1
    continue
  fi

  if diff -q "${src}" "${dest}" > /dev/null 2>&1; then
    echo "OK    ${f} (byte-identical to configs/${f})"
  else
    echo "DRIFT ${f} differs from configs/${f}:"
    diff -u "${src}" "${dest}" || true
    status=1
  fi
done

echo
echo "Cross-check against configs/CHECKSUMS.txt (canonical hashes):"
(
  cd "${SRC_DIR}"
  grep -E "$(printf '%s|' "${FILES[@]}" | sed 's/|$//')" CHECKSUMS.txt | sha256sum -c -
) || status=1

exit "${status}"
