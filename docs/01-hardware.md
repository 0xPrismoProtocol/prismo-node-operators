# Hardware Requirements

Sized against the live testnet chain (measured 2026-07: cdk-erigon datadir ~6 GB, resident memory ~300 MB — a young, low-traffic chain). The numbers below are a **comfortable minimum with headroom for growth**, not a hard floor: chain state, tx volume, and disk usage all grow over time, and mainnet load is unknown pre-launch. Re-evaluate periodically, and definitely before mainnet.

## Per Node Role

| Role | vCPU | RAM | Disk | Disk type | Network | Notes |
|------|-----:|----:|-----:|-----------|--------:|-------|
| RPC Node | 4 | 8 GB | 100 GB | NVMe SSD | 100 Mbps | Comfortable minimum with growth headroom; see Disk Growth below |
| Full Node (state-verifying) | 4 | 8 GB | 100 GB | NVMe SSD | 100 Mbps | Same as RPC + reliable L1 archive access |
| Watchtower | 2 | 4 GB | 50 GB | SSD | 25 Mbps | Plus query access to a full node |
| Bridge Indexer | 4 | 8 GB | 200 GB | SSD | 25 Mbps | Postgres on same host or external |

For mainnet, plan for at least double these resources as a starting assumption until real load data exists — mainnet chain size, tx volume, and the L1 fee market will all push requirements up, but by how much is genuinely unknown before launch.

## Disk Growth

**Archive is the shipped default** (see [Pruning vs archive](nodes/rpc-node.md#pruning-vs-archive) — required for snapshot restores and reference-tier parity). Pruned mode is an opt-in for a fresh genesis sync only; it cannot be applied to a running or snapshot-restored datadir.

Estimated growth per month at current testnet load:

| Role | Archive (shipped default) | Pruned (opt-in, fresh sync only) |
|---|---:|---:|
| RPC Node | ~150 GB | ~30 GB |
| Full Node | ~150 GB | ~30 GB |
| Bridge Indexer | ~5 GB | n/a |

These are growth *rates*, not current size — the live chain's actual datadir today is ~6 GB (see above); it will grow toward these figures as chain age and tx volume increase. Mainnet figures will be revised once load data is in. The 100 GB in the table above is a *starting* floor — under one month of archive-mode growth — so provision extra (or a resizable) volume from day one; the cloud Terraform modules default to 1 TB for exactly this reason.

## L1 Dependency

Every L2 node needs an L1 RPC endpoint on the network it follows.

| Network | L1 | Self-host option | Public-RPC option |
|---|---|---|---|
| Testnet | Sepolia | geth/reth + lighthouse/prysm, ~1 TB | Alchemy / Infura / Ankr / dRPC |
| Mainnet | Ethereum | geth/reth + lighthouse/prysm, ~2.5 TB | Alchemy / Infura / Ankr / dRPC |

Recommendation:

- **Self-host for full nodes and watchtowers** — they hammer L1 during catch-up; public providers will rate-limit.
- **Public RPC is fine for an RPC node** that consumes the sequencer data stream and only does light L1 reads.
- **Run inside same compose / k8s** as the L2 node: see [deploy/docker-compose/full-node](../deploy/docker-compose/full-node/) for combined setup. The compose template selects `--sepolia` or `--mainnet` from `L1_NETWORK_FLAG` in the active network env.

## Cloud Sizing Reference

| Provider | RPC node | Full node | Watchtower | Bridge indexer |
|---|---|---|---|---|
| AWS | `c6i.xlarge` (4 vCPU/8 GB) + 100 GB gp3 | `c6i.xlarge` + 100 GB gp3 | `t3.medium` + 50 GB gp3 | `t3.large` + 200 GB gp3 |
| Hetzner | `CPX31` (4 vCPU/8 GB) + 160 GB NVMe | `CPX31` + 160 GB NVMe | `CX22` + 80 GB | `CCX13` + 240 GB |
| GCP | custom `n2-custom-4-8192` (4 vCPU/8 GB) + 100 GB pd-ssd | `n2-custom-4-8192` + 100 GB pd-ssd | `e2-medium` + 50 GB pd-ssd | `e2-standard-2` + 200 GB pd-ssd |

The instances in the table above are the minimum-matching tier. The cloud Terraform modules under [deploy/cloud/](../deploy/cloud/) deliberately default to a larger **headroom** tier — AWS `m6i.2xlarge` + 1 TB gp3 (~$374/mo) and Hetzner `CCX23` (dedicated AMD) + 1 TB (~€62/mo), not the `CPX31` in the table above — see each module's README. This is intentional production headroom, not a hard requirement; the table values still meet the documented minimum.

Monthly cost rough order (comfortable-minimum sizing above): AWS ~$110, Hetzner ~$20, GCP ~$120 for the RPC tier. Bump disk size well before you hit these numbers if you're tracking Disk Growth above — resizing a live volume is easier than an emergency migration.

## Latency Considerations

- Sequencer data stream is in `us-east-1` (testnet; mainnet location TBD). RPC nodes in Asia/EU lag ~150–250 ms behind sequencer head — fine for normal use.
- Watchtowers can run anywhere — they only read L1 events.
- Bridge indexer is read-mostly; latency unimportant.
