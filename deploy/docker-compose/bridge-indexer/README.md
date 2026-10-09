# Bridge Indexer — Docker Compose

Self-hosted `zkevm-bridge-service` + Postgres. Provides Merkle proofs for users claiming withdrawals on L1. Works on either network — `NETWORK=testnet` or `NETWORK=mainnet`.

## Steps

```bash
cd deploy/docker-compose/bridge-indexer
cp .env.example .env
# Edit .env — pick NETWORK; set L1_RPC_URL, L2_RPC_URL, DB_PASS

# Bridge contract addresses (BRIDGE_L1, BRIDGE_L2) come from the active
# configs/networks/${NETWORK}.env — testnet: 0xd7d4F6BFD45C3EaEFde6fAEc0920fBC7E5a71D0d
# (2026-06-27 re-genesis); mainnet: 0xB6F289768b02dB5983E41D2BeA04E23e356fEbA4
# (2026-10-07 genesis). If they ever change, patch that file, not config.toml here.
# Mainnet note: L1 settlement is not yet enabled, so withdrawals cannot be
# claimed there yet (deposits index normally) — see docs/02-network-config.md.

../../../scripts/compose.sh bridge-indexer up -d
../../../scripts/compose.sh bridge-indexer logs -f bridge-service
```

## Smoke test

```bash
curl -s http://localhost:8080/healthz
curl -s 'http://localhost:8080/bridges/0x0000000000000000000000000000000000000000?limit=10'
```

## Diff against the official indexer

```bash
set -a; . ../../../configs/networks/$(awk -F= '/^NETWORK=/{print $2}' .env).env; set +a
curl -s "${BRIDGE_API_URL}/merkle-proof?net_id=0&deposit_cnt=1" > a.json
curl -s "http://localhost:8080/merkle-proof?net_id=0&deposit_cnt=1" > b.json
diff <(jq -S . a.json) <(jq -S . b.json)
```

A non-empty diff (modulo timestamps) means one of the two indexers is wrong.

## DB

Postgres ships in this compose. For production (especially mainnet), prefer external managed Postgres and remove the `postgres` service.
