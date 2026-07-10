#!/usr/bin/env bash
# Tail the sync gap of a Prismo node every 10 s.
# Usage: ./sync-progress.sh [http://localhost:8545]
#
# Network-agnostic — the script only prints block / batch / verified-batch counters.
# For chain-id verification, use scripts/healthcheck.sh.
set -euo pipefail
RPC="${1:-http://localhost:8545}"
while true; do
  BLOCK=$(curl -fsS -X POST "$RPC" -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    | jq -r .result)
  BATCH=$(curl -fsS -X POST "$RPC" -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"zkevm_batchNumber","params":[],"id":1}' \
    | jq -r .result 2>/dev/null || echo "0x0")
  VERIFIED=$(curl -fsS -X POST "$RPC" -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"zkevm_verifiedBatchNumber","params":[],"id":1}' \
    | jq -r .result 2>/dev/null || echo "0x0")
  printf "%s  block=%s  batch=%s  verified=%s\n" \
    "$(date -u +%H:%M:%S)" "$((BLOCK))" "$((BATCH))" "$((VERIFIED))"
  sleep 10
done
