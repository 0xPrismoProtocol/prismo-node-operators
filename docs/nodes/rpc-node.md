# RPC Node

Read-only `cdk-erigon` instance serving JSON-RPC. Lowest barrier to entry — start here.

## What it does

1. Connects outbound to the sequencer's data stream (`${DATASTREAM_HOST}:${DATASTREAM_PORT}`) for new blocks.
2. Reads batch and event data from an L1 RPC (Sepolia for testnet, Ethereum for mainnet — picked by `NETWORK`).
3. Re-executes blocks locally to build state.
4. Serves user `eth_*`, `net_*`, `web3_*`, `txpool_*`, `zkevm_*` calls on `:8545`.

It does **not**:
- Sign or seal blocks
- Hold keys
- Order transactions (sequencer's job)
- Generate proofs

## Why run one

- **Decentralizes the read path.** A single official RPC = single point of failure.
- **You can offer it as a service** (paid or free), join public RPC registries, or use it for your own dapp.
- **Insurance against rate-limits**: if your dapp depends on a third-party RPC and they throttle you, your own node continues.

## Inputs needed

| Input | Source | Notes |
|---|---|---|
| L1 RPC URL | Self-hosted or Alchemy/Infura | Read-only, ~1 req/s steady-state. Sepolia (testnet) or Ethereum (mainnet) |
| Sequencer data stream host:port | `${DATASTREAM_HOST}:${DATASTREAM_PORT}` from active `configs/networks/<NETWORK>.env` | Plain TCP, outbound |
| Network selection | `NETWORK=testnet` or `NETWORK=mainnet` | Loads matching contracts + chain IDs |
| Chain config | This repo, `configs/` | Mounted at `/etc/prismo/` |

## Quick start (Docker Compose)

```bash
cd deploy/docker-compose/rpc-node
cp .env.example .env
# Edit .env: set NETWORK (testnet|mainnet) and L1_RPC_URL

# Use the wrapper, not `docker compose` directly — it layers
# configs/networks/<NETWORK>.env under this .env, which is where the chain
# ID, contract addresses, and datastream host come from. Plain `docker
# compose up -d` renders every ${...} flag empty and cdk-erigon fails to start.
../../../scripts/compose.sh rpc-node up -d
../../../scripts/compose.sh rpc-node logs -f cdk-erigon
```

## Quick start (systemd)

```bash
cd deploy/systemd/rpc-node
sudo bash install.sh
# Required: install.sh writes /etc/prismo/env with a placeholder L1_RPC_URL —
# the service will not sync until you point it at a real L1 endpoint.
sudo nano /etc/prismo/env        # set L1_RPC_URL
sudo systemctl enable --now cdk-erigon
journalctl -u cdk-erigon -f
```

## Quick start (Kubernetes)

```bash
# From repo root. The vendored chart lives at deploy/kubernetes/chart; each
# role directory only carries its own values.yaml overrides.
helm install prismo-rpc ./deploy/kubernetes/chart \
  -f deploy/kubernetes/rpc-node/values.yaml \
  -n prismo --create-namespace
kubectl logs -n prismo -l app=prismo-rpc -f
```

## Quick start (cloud)

```bash
cd deploy/cloud/aws/rpc-node    # or hetzner/rpc-node
terraform init
terraform apply
```

## Health checks

```bash
# Sync status (false = synced)
curl -s -X POST http://localhost:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}'

# Latest block
curl -s -X POST http://localhost:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# zkevm-specific: latest verified batch
curl -s -X POST http://localhost:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"zkevm_verifiedBatchNumber","params":[],"id":1}'
```

Convenience: `scripts/healthcheck.sh`.

## Pruning vs archive

**Default: unpruned (archive).** The shipped [`configs/chain-config.yaml`](../../configs/chain-config.yaml) does not set `prune` at all, so full historical state, headers, and receipts are retained (serves `debug_traceTransaction` for any historical block, if you enable `debug` in `http.api` — see [04-security.md](../04-security.md)). Two reasons this is the default rather than pruned:

1. **Published snapshots are unpruned.** cdk-erigon hard-refuses to change `--prune` mode on an existing datadir ("not allowed change of `--prune` flag") — a node restored from a [published snapshot](../03-snapshots.md) can never switch to pruned later.
2. **Reference-tier parity.** The public reference RPC (`rpc.glassnet.prismo.network`) runs unpruned; a pruned node behind it would silently serve less history than the tier it's supposed to complement.

Disk grows accordingly with chain size — see [01-hardware.md](../01-hardware.md) for current numbers; there's no fixed floor to plan against, only headroom.

### Opt-in pruning (fresh genesis sync only)

If you're syncing from genesis (not from a snapshot) and don't need historical trace/log depth, uncomment in `configs/chain-config.yaml` **before the first start** — pruned mode cannot be toggled on afterward:

```yaml
prune: hrtc
prune.h.older: 90000
prune.r.older: 90000
prune.t.older: 90000
prune.c.older: 90000
```

Flag spellings verified against cdk-erigon v2.61.24: prune categories are the single letters `h` (history), `r` (receipts), `t` (tx lookup), `c` (call traces), each with an optional `.older` retention window. `prune.history` / `prune.receipt` / `prune.txindex` / `prune.calltrace` are **not** real flags — they're silently no-ops if you set them.

A pruned node cannot serve `debug_traceTransaction` for old blocks and cannot be un-pruned without a full resync.

## Exposing to the public

See [docs/04-security.md](../04-security.md). Short version:

1. Put nginx in front for TLS + rate-limit.
2. Restrict `http.api` to `eth, net, web3, txpool, zkevm`.
3. Block `admin_*`, `personal_*`, `miner_*` at the proxy.
4. Bind cdk-erigon HTTP to `127.0.0.1`, only the proxy listens publicly.

## Listing your RPC publicly

Once running, register at:

- (TBD) `https://chainlist.testnet.prismo.example` — Prismo testnet RPC registry
- (TBD) `https://chainlist.prismo.example` — Prismo mainnet RPC registry
- (Optional) [chainlist.org](https://chainlist.org) for mainnet
