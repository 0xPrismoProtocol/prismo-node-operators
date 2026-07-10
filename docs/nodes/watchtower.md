# Watchtower

> **Not runnable yet.** The watchtower binary has not been released or
> open-sourced. `ghcr.io/0xprismoprotocol/watchtower` does not resolve —
> pulling it will fail, and that is expected. Until a real image ships, this
> role is **documentation-only**: read this page to understand the design,
> but do not run the Quick Start below expecting a working container.

Lightweight service that watches L1 rollup contract events and alarms on misbehavior. The fraud-detection layer for Prismo while the sequencer remains centralized.

## What it does

For every L1 event of interest, the watchtower:

1. **`SequenceBatches(uint64 numBatch)`** — sequencer posted a new batch range. Record `(batchNum, l1TxHash, l1Block)`.
2. **`VerifyBatches(uint64 numBatch, bytes32 stateRoot, address aggregator)`** — aggregator posted a SNARK proof and a claimed state root. Watchtower:
   - Queries a local **full node** for the state root at `batchNum`.
   - Compares with the L1-claimed root.
   - If mismatch → fires alert (`PrismoFraudDetected`).
3. **`UpdateRollupManager*` / `Upgraded` / admin events** — alerts on governance actions (immediate notice of any contract upgrade).

## What it does NOT do

- It does not send transactions, slash, or challenge — that is the protocol's job (or, on testnet, manual incident response).
- It does not validate SNARKs — the L1 verifier already does.
- It is not authoritative — its job is to *raise alarm*. Operator + community decide what to do.

## Why run one

- Earliest signal of an aggregator/verifier compromise.
- Provides cryptographic proof of misbehavior (event, claimed root, your computed root) usable for public disclosure.
- No special permission to run — anyone can.

## Architecture

```
[ L1 (Sepolia or Ethereum) ] ----events----> [ watchtower ]
                                                    |
                                                    | RPC: zkevm_getBatchByNumber
                                                    v
                                          [ Prismo full node ]
                                                    |
                                                    | comparison
                                                    v
                                  [ alerts: webhook / email / Slack / Discord / Twitter ]
```

## Inputs

| Input | Purpose |
|---|---|
| `NETWORK` | Selects which contract addresses + chain IDs to watch |
| L1 RPC URL | Subscribe to logs (Sepolia for testnet, Ethereum for mainnet) |
| L2 full-node URL | Fetch state roots to compare against L1 claims |
| Webhook URL(s) | Where to post alerts |

## Configuration sketch

All addresses, chain IDs, and the L1 first block come from the active `configs/networks/<NETWORK>.env`. The watchtower process reads them as env vars; only the alert sinks are operator-specific.

```yaml
# config.yaml — values templated from the active network env
l1:
  rpc_url: "${L1_RPC_URL}"
  rollup_contract: "${ROLLUP_CONTRACT}"
  ger_manager:     "${GER_MANAGER}"
  start_block:     ${L1_FIRST_BLOCK}
  poll_interval_seconds: 12
  finality_blocks: 64    # wait this many before treating event as final

l2:
  rpc_url: "http://localhost:8545"
  expected_chain_id: ${L2_CHAIN_ID}

alerts:
  webhooks:
    - url: "${SLACK_WEBHOOK_URL}"
      type: slack
    - url: "${DISCORD_WEBHOOK_URL}"
      type: discord
  cooldown_seconds: 300

severity_routing:
  fraud_detected: page         # state root mismatch → on-call page
  upgrade: page                # any contract upgrade → page
  sequencer_silent: warn       # no SequenceBatches in 4 h → warn (see cadence note)
```

## Expected event cadence (testnet)

Tune silence thresholds to the chain's actual rhythm, or they will flap:

- **`SequenceBatches`**: batches seal after 1 h idle (`zkevm.sequencer-batch-seal-time=1h` since the 2026-06-27 re-genesis), so on a quiet testnet expect roughly **one sequencing tx per 1–2 h**. The bundled alert rule warns after 4 h.
- **`VerifyBatches`**: proving is **windowed** — the prover runs 02:00–06:00 UTC daily, so proofs arrive in a **daily burst**, not continuously. Up to ~24 h between bursts is normal; the bundled alert warns after 36 h. A growing verified-batch lag *within* a day is not an incident.
- Sequencing txs on L1 come from the trusted sequencer EOA `TRUSTED_SEQUENCER_L1`; verification txs come from the aggregator EOA (see `configs/networks/testnet.env`).

## What constitutes "fraud detected"

Strict: any L1-claimed `stateRoot` for batch N that does not equal the state root your local full node has at batch N, *after* both sides have observed enough finality (`finality_blocks` for L1, your full node fully synced past N).

False positives are usually:

- Full node behind L1 — wait, retry.
- Snapshot-restored full node disagreeing with full sync — re-sync from genesis on a separate full node before declaring fraud.

Always corroborate before public disclosure.

## Quick start

```bash
cd deploy/docker-compose/watchtower
cp .env.example .env

# Use the wrapper, not `docker compose` directly — it layers
# configs/networks/<NETWORK>.env under this .env so contract addresses and
# chain IDs actually resolve.
../../../scripts/compose.sh watchtower up -d
../../../scripts/compose.sh watchtower logs -f
```

## Operational notes

- Run **at least two** independent watchtowers backed by **different** full nodes. A single watchtower with a buggy backend is a liability.
- Watchtowers are write-light, read-heavy. Cache aggressively.
- Persist all observed events; this is your audit log if an incident occurs.
- Subscribe to alerts in a channel that on-call actually watches.
