# Bridge Indexer

`zkevm-bridge-service` is the upstream service that indexes deposit and withdrawal events on both L1 and L2, builds Merkle proofs, and exposes them via HTTP API. Users querying it can construct the proof needed to **claim** withdrawals on L1 or deposits on L2.

## What it does

1. Subscribes to events on the L1 `PolygonZkEVMBridge` contract.
2. Subscribes to events on the L2 bridge contract (precompile-like address).
3. Indexes each `BridgeEvent(network, originAddress, destinationAddress, amount, leafType, depositCount, ...)`.
4. Maintains a sparse Merkle tree of bridge leaves; serves `/merkle-proof` endpoint.
5. Provides REST API: list a user's deposits, fetch claim proof, watch status.

## Why run one

If the official bridge UI / indexer is censoring, throttled, or offline, users still need a way to claim assets out of L2. The contract layer is permissionless — anyone with the right Merkle proof can call `claimAsset()` / `claimMessage()`. An independent indexer ensures the *proof* is also permissionless.

This is one of the most user-protective public services possible.

## Inputs

| Input | Purpose |
|---|---|
| `NETWORK` | Selects testnet (Sepolia) or mainnet (Ethereum) contract set |
| L1 RPC | Read bridge contract events |
| L2 RPC (your own RPC node ideally) | Read L2 bridge events |
| Postgres database | Indexed events + Merkle tree |
| Bridge contract addresses | From `configs/networks/<NETWORK>.env` (`BRIDGE_L1`, `BRIDGE_L2`) — see [02-network-config.md](../02-network-config.md) |

## Configuration

Upstream config format is TOML. Skeleton in `deploy/docker-compose/bridge-indexer/config.toml`:

```toml
[Log]
Level = "info"
Outputs = ["stdout"]

[NetworkConfig]
GenBlockNumber = ${L1_FIRST_BLOCK}
PolygonBridgeAddress = "${BRIDGE_L1}"
PolygonZkEVMGlobalExitRootAddress = "${GER_MANAGER}"
PolygonRollupManagerAddress = "${ROLLUP_CONTRACT}"
L2PolygonBridgeAddresses = ["${BRIDGE_L2}"]

[Etherman]
L1URL = "${L1_RPC_URL}"
L2URLs = ["${L2_RPC_URL}"]

[BridgeServer]
Host = "0.0.0.0"
Port = 8080
DB = { Database = "postgres", User = "bridge", Password = "${DB_PASS}", Host = "postgres", Port = "5432", Name = "bridge", MaxConns = 20 }
```

> Bridge contracts (`BRIDGE_L1`, `BRIDGE_L2`): testnet `0xd7d4F6BFD45C3EaEFde6fAEc0920fBC7E5a71D0d` (2026-06-27 re-genesis); mainnet `0xB6F289768b02dB5983E41D2BeA04E23e356fEbA4` (2026-10-07 genesis). Same address on L1 and L2 on both networks.
>
> **Mainnet:** L1 settlement is not yet enabled, so no global exit roots are verified on L1 and L2→L1 withdrawals cannot be claimed yet. Deposits (L1→L2) index normally. See [02-network-config.md](../02-network-config.md#mainnet-facts-operators-must-know).

## API surface (read-only)

```
GET /bridges/<address>          # deposits/withdrawals for an address
GET /merkle-proof?net_id=&deposit_cnt=
GET /claims/<address>           # claim status
GET /health
```

These are safe to expose publicly behind a TLS reverse proxy and rate-limit.

## Quick start

```bash
cd deploy/docker-compose/bridge-indexer
cp .env.example .env
# Set L1_RPC_URL, L2_RPC_URL, DB_PASS

# Use the wrapper, not `docker compose` directly — it layers
# configs/networks/<NETWORK>.env under this .env so bridge/rollup contract
# addresses actually resolve.
../../../scripts/compose.sh bridge-indexer up -d
../../../scripts/compose.sh bridge-indexer logs -f bridge-service
```

Postgres ships in the same compose file by default.

## Verifying correctness

Two indexers indexing the same chain should produce **identical** Merkle proofs for the same `(net_id, deposit_cnt)`. Cross-check yours against the official bridge service:

```bash
# Use BRIDGE_API_URL from the active network env to pick testnet vs mainnet.
curl "${BRIDGE_API_URL}/merkle-proof?net_id=0&deposit_cnt=42" > a.json
curl http://localhost:8080/merkle-proof?net_id=0&deposit_cnt=42 > b.json
diff <(jq -S . a.json) <(jq -S . b.json)
```

Diff should be empty modulo timestamps. If proofs differ, one indexer is wrong.

## Database growth

~5 GB / month on testnet. Mainnet TBD — provision at least 2× testnet rates as a starting point.

## Alerts

- `PrismoBridgeIndexerLag` — last indexed L1 block more than 200 blocks behind chain head
- `PrismoBridgeAPIErrors` — 5xx rate > 1/s for 5 min
- `PrismoBridgeProofMismatch` — diff job vs official indexer non-empty (run hourly)
