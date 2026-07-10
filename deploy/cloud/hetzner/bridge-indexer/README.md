# Bridge Indexer — Hetzner

`CCX13` (~€20/mo, 2 vCPU AMD, 8 GB) + 240 GB volume for Postgres + state on testnet; sized up for mainnet (CCX23 + 500 GB+). Adapt `../rpc-node/main.tf` accordingly and pass `network=testnet|mainnet`.

Hetzner has no managed Postgres equivalent to RDS — either run Postgres in the same compose, or use a separate VPS for it (Hetzner private network keeps it off the internet). For mainnet, a managed Postgres elsewhere is the safer pick.
