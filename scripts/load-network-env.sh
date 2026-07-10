#!/usr/bin/env bash
# Print the canonical env file for a given network.
# Usage: ./load-network-env.sh <testnet|mainnet>
# Output: contents of configs/networks/<network>.env, or exit 1 if unknown.
set -euo pipefail

NET="${1:?network required (testnet|mainnet)}"
case "$NET" in
  testnet|mainnet) ;;
  *) echo "unknown network: $NET (allowed: testnet, mainnet)" >&2; exit 1 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../configs/networks/${NET}.env"
[[ -f "$FILE" ]] || { echo "missing: $FILE" >&2; exit 1; }

cat "$FILE"
