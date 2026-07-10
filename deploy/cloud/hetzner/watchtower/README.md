# Watchtower — Hetzner

`CX22` (€4/mo, 2 vCPU, 4 GB) is plenty. Adapt `../rpc-node/main.tf` (`server_type = "cx22"`, drop the volume, swap the compose path). Pass `network=testnet` or `network=mainnet`.

Run at least one watchtower per network you have skin in the game on.
