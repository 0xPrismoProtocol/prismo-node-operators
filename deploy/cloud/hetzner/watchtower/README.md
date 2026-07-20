# Watchtower — Hetzner

> **Not runnable yet** — the watchtower binary is unpublished (`ghcr.io/0xprismoprotocol/watchtower` does not resolve). Documentation-only until an image ships; see [docs/nodes/watchtower.md](../../../../docs/nodes/watchtower.md).

`CX22` (€4/mo, 2 vCPU, 4 GB) is plenty. Adapt `../rpc-node/main.tf` (`server_type = "cx22"`, drop the volume, swap the compose path). Pass `network=testnet` or `network=mainnet`.

Run at least one watchtower per network you have skin in the game on.
