# Watchtower — Docker Compose

> **Not runnable yet.** The watchtower binary has not been released or
> open-sourced. `ghcr.io/0xprismoprotocol/watchtower` does not resolve —
> pulling it will fail, and that is expected. Until a real image ships, this
> role is **documentation-only**: read it to understand the design, but do
> not run the quickstart below expecting a working container.

## Steps

```bash
cd deploy/docker-compose/watchtower
cp .env.example .env
# Edit .env — pick NETWORK (testnet|mainnet), point L2_RPC_URL at your full node, add a webhook
../../../scripts/compose.sh watchtower up -d
../../../scripts/compose.sh watchtower logs -f
```

## Prerequisites

- A reachable **L2 full node on the SAME network** (not RPC node — full node re-derives state from L1, which is what the comparison requires). See [docs/nodes/full-node.md](../../../docs/nodes/full-node.md).
- An L1 RPC matching the network (Sepolia for testnet, Ethereum for mainnet).
- At least one alert sink (Slack/Discord webhook, or extend config to add PagerDuty/email).

## Image note

`ghcr.io/0xprismoprotocol/watchtower:0.1.0` is a placeholder reference image. Replace with a community-maintained build, or use the source under `cmd/watchtower/` (TODO — to be open-sourced) and `docker build`.

## What "fraud detected" means

The watchtower has caught a **state root mismatch** between the L1-claimed root for batch N and your local full node's computed root for batch N, after both sides have observed enough finality. **Page on-call. Do not panic-trade. Corroborate with at least one other independent watchtower before public disclosure.**

## Run two — and one per network

A single watchtower with one full node behind it is one trust assumption. Run two, in different regions, with different L1 RPC providers. Once mainnet launches, run one watchtower stack per network — they're independent, just `NETWORK=` differs.
