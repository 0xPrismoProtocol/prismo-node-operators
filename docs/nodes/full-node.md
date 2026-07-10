# Full Node (state-verifying)

Same `cdk-erigon` binary as the RPC node, but configured to **derive state from L1 data**, not from the sequencer's stream. The result: independent verification that the sequencer/aggregator is posting correct data.

## What it does (differently from RPC)

| Aspect | RPC node | Full node |
|---|---|---|
| Source of new blocks | Sequencer data stream | L1 batches (blobs / calldata on Sepolia or Ethereum) |
| Trust in sequencer | Trusts data stream feed | Trusts only L1 |
| Latency to head | ~seconds | ~minutes (waits for L1 batch posting) |
| Catches sequencer fraud | No | Yes — re-derives state, fails if root mismatches |
| Use case | Serving users | State verification, watchtower backend, archive |

## Why run one

- Independent re-execution of every batch. If the aggregator ever submits a state root that disagrees with what the L1 calldata implies, your node screams.
- Backend for watchtowers — they query a full node to compute the "expected" state root.
- Strongest trust-minimized read path: bridge UIs and indexers should prefer full nodes over RPC nodes.

## Configuration delta vs RPC

Same `configs/` files, but with these flags overridden:

```yaml
# Disable trusting the sequencer's stream
zkevm.l2-datastreamer-url: ""        # leave empty
zkevm.sync-from-l1-only: true        # all blocks come from L1

# Stricter executor
zkevm.executor-strict: true
zkevm.l1-contract-address-check: true
```

These are pre-applied in `deploy/*/full-node/` configs.

## Required: reliable L1 archive access

A full node makes **many more L1 calls** than an RPC node, especially during catch-up:

- Reads every batch's calldata / blob
- Reads every `SequenceBatches` and `VerifyBatches` event from `L1_FIRST_BLOCK` (per the active network env) to head

Public L1 endpoints will rate-limit you during the initial sync. Strongly recommended: run a self-hosted L1 full node (geth + lighthouse) on the same host, or peer with one over a private network. Pick the L1 by `NETWORK`:

| `NETWORK` | L1 to run | Disk |
|---|---|---|
| `testnet` | Sepolia (`--sepolia`) | ~1 TB |
| `mainnet` | Ethereum (`--mainnet`) | ~2.5 TB |

The Docker Compose layout in `deploy/docker-compose/full-node/` includes geth + lighthouse alongside cdk-erigon, with the L1 network flag picked from `L1_NETWORK_FLAG` in the active network env.

## Verification scenarios

### Scenario A: aggregator posts a valid root
- Your local execution matches L1.
- No alerts. Healthy.

### Scenario B: aggregator posts an *invalid* root
- L1 verifier should reject the SNARK proof — this is the cryptographic guarantee.
- If the proof is somehow accepted, your node logs `state root mismatch at batch N` and refuses to advance.
- File an incident. This is what zk-rollups call "the bad day" — extremely unlikely under correct verifier code, but watchtowers exist for it.

### Scenario C: data unavailable (rollup mode shouldn't happen, validium can)
- Pure rollup posts data on L1 blobs. If a batch's data is missing, your node halts at that batch and logs `unable to fetch batch data`.
- Recovery: wait for sequencer to repost, or for governance to take action.

## Quick start

```bash
cd deploy/docker-compose/full-node
cp .env.example .env
# Edit .env — pick NETWORK; L1 client follows L1_NETWORK_FLAG automatically

# Use the wrapper, not `docker compose` directly — it layers
# configs/networks/<NETWORK>.env under this .env so chain ID, contract
# addresses, and the L1 network flag actually resolve.
../../../scripts/compose.sh full-node up -d
```

Initial sync takes longer than RPC mode because all blocks are derived from L1. Plan for hours, not minutes (and longer for mainnet). Use a snapshot ([03-snapshots.md](../03-snapshots.md)) to skip historical state.

## Health checks specific to full nodes

```bash
# Latest L1-derived batch
curl -s -X POST http://localhost:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"zkevm_batchNumber","params":[],"id":1}'

# Latest verified batch (proven on L1)
curl -s -X POST http://localhost:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"zkevm_verifiedBatchNumber","params":[],"id":1}'

# Gap = how far behind verification this node is
```

## Alerts

Besides the standard alert set, full nodes should fire on:

- `PrismoFullNodeStateRootMismatch` — `BadBlock` log line — **page immediately**
- `PrismoFullNodeBatchDataMissing` — node halted waiting for L1 data — page within 15 min
