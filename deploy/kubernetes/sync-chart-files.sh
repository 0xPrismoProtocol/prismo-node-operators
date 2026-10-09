#!/usr/bin/env bash
# Re-copies every chain-file set (configs/dynamic-<chain>-{allocs,conf,chainspec}.json
# — one set per network: dynamic-glassnet-* for testnet, dynamic-glass-* for
# mainnet) into deploy/kubernetes/chart/files/, then diffs to confirm they are
# byte-identical.
#
# Why this exists: chart/templates/configmap.yaml embeds the set selected by
# config.chainName via `.Files.Get` — Helm can only read files from inside the
# chart directory, so the canonical copies in configs/ (also used by the
# docker-compose and systemd targets) must be mirrored into chart/files/. There
# is no symlink or build step that keeps them in sync automatically; run this
# script after touching any configs/dynamic-*.json file, after a chain reset,
# or after adding a network.
#
# Independent verification: configs/CHECKSUMS.txt carries the sha256 of the
# canonical configs/ copies. After running this script, `sha256sum -c` against
# that file from the chart/files/ directory should also pass, since the copies
# are byte-identical.
#
# Usage: deploy/kubernetes/sync-chart-files.sh [--check]
#   (no args)  copy configs/dynamic-*.json -> chart/files/, then diff
#   --check    diff only, do not copy (exits non-zero on drift; CI-friendly)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SRC_DIR="${REPO_ROOT}/configs"
DEST_DIR="${SCRIPT_DIR}/chart/files"

# Every dynamic-<chain>-{allocs,conf,chainspec}.json in configs/ is canonical.
FILES=()
for f in "${SRC_DIR}"/dynamic-*-allocs.json "${SRC_DIR}"/dynamic-*-conf.json "${SRC_DIR}"/dynamic-*-chainspec.json; do
  [[ -f "${f}" ]] && FILES+=("$(basename "${f}")")
done
if [[ "${#FILES[@]}" -eq 0 ]]; then
  echo "ERROR: no configs/dynamic-*-{allocs,conf,chainspec}.json found" >&2
  exit 1
fi

CHECK_ONLY=0
if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY=1
fi

mkdir -p "${DEST_DIR}"

status=0
for f in "${FILES[@]}"; do
  src="${SRC_DIR}/${f}"
  dest="${DEST_DIR}/${f}"

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

# Every chain set must be complete: a chainName with a missing member fails
# the chart render (templates/configmap.yaml), so catch it here first.
for chain in $(printf '%s\n' "${FILES[@]}" | sed -E 's/^(dynamic-.*)-(allocs|conf|chainspec)\.json$/\1/' | sort -u); do
  for part in allocs conf chainspec; do
    if [[ ! -f "${DEST_DIR}/${chain}-${part}.json" ]]; then
      echo "ERROR: chain '${chain}' is missing ${chain}-${part}.json" >&2
      status=1
    fi
  done
done

echo
echo "Cross-check chart/files/ against configs/CHECKSUMS.txt (canonical hashes):"
(
  cd "${DEST_DIR}"
  grep -E "  dynamic-[a-z0-9-]+-(allocs|conf|chainspec)\.json$" "${SRC_DIR}/CHECKSUMS.txt" | sha256sum -c -
) || status=1

exit "${status}"
