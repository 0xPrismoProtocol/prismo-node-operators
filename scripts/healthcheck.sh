#!/usr/bin/env bash
# Quick health check for any Prismo cdk-erigon node (RPC or full).
# Usage: ./healthcheck.sh [http://localhost:8545] [testnet|mainnet]
#
# If the network arg is omitted, $NETWORK from the environment is used (default: testnet).
# The expected L2 chain ID is read from configs/networks/<network>.env so the
# same script works for both networks.
set -euo pipefail

RPC="${1:-http://localhost:8545}"
NETWORK="${2:-${NETWORK:-testnet}}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NET_FILE="$SCRIPT_DIR/../configs/networks/${NETWORK}.env"
[[ -f "$NET_FILE" ]] || { echo "unknown NETWORK=$NETWORK (no $NET_FILE)" >&2; exit 1; }

# shellcheck disable=SC1090
EXPECTED_CHAIN_ID="$(awk -F= '/^L2_CHAIN_ID=/{print $2}' "$NET_FILE")"

call() {
  curl -fsS -X POST "$RPC" \
    -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"$1\",\"params\":${2:-[]},\"id\":1}"
}

echo "Endpoint: $RPC"
echo "Network:  $NETWORK  (expected L2_CHAIN_ID=$EXPECTED_CHAIN_ID)"
echo "----"

CHAIN_ID_HEX=$(call eth_chainId | jq -r .result)
CHAIN_ID=$((CHAIN_ID_HEX))
echo "chainId: $CHAIN_ID"

if [[ "$EXPECTED_CHAIN_ID" == "TBD" ]]; then
  echo "WARN: $NETWORK L2_CHAIN_ID is TBD in configs/networks/${NETWORK}.env — skipping match check"
elif [[ "$CHAIN_ID" != "$EXPECTED_CHAIN_ID" ]]; then
  echo "FAIL: chain mismatch (got $CHAIN_ID, expected $EXPECTED_CHAIN_ID for $NETWORK)"
  exit 1
fi

SYNC=$(call eth_syncing | jq -r .result)
echo "syncing: $SYNC"

BLOCK_HEX=$(call eth_blockNumber | jq -r .result)
BLOCK=$((BLOCK_HEX))
echo "blockNumber: $BLOCK"

BATCH_HEX=$(call zkevm_batchNumber | jq -r .result 2>/dev/null || echo "0x0")
BATCH=$((BATCH_HEX))
VERIFIED_HEX=$(call zkevm_verifiedBatchNumber | jq -r .result 2>/dev/null || echo "0x0")
VERIFIED=$((VERIFIED_HEX))
echo "batchNumber: $BATCH"
echo "verifiedBatchNumber: $VERIFIED"
echo "verification gap: $((BATCH - VERIFIED)) batches"

if [[ "$SYNC" != "false" ]]; then
  echo "STATUS: syncing"
  exit 2
fi
echo "STATUS: ok"
