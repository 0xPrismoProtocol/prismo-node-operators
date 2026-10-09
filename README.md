# Prismo Node Operators

Run public infrastructure for the **Prismo zkEVM** (Polygon CDK Erigon rollup) — **Prismo Glass mainnet** (chain 328, settling to Ethereum) and the **Glassnet testnet** (chain 101001000, settling to Sepolia), from the same manifests.

This repository contains everything an external operator needs to run **non-sequencer** nodes: configuration, deploy manifests for four targets, monitoring rules, and operational guides.

> **Status:** Mainnet live since 2026-10-07 (genesis root `0x8d57491b…`); testnet live. The sequencer and aggregator are operated by the Prismo core team. All node roles in this repo are permissionless to run. **Read [Mainnet facts operators must know](docs/02-network-config.md#mainnet-facts-operators-must-know) before running a mainnet node** — mainnet accepts only legacy (type-0) transactions and does not yet post batches or proofs to L1.

---

## Network selection

Every deploy target reads a single `NETWORK` variable. Canonical per-network values live in [`configs/networks/`](configs/networks/).

| Network | `NETWORK=` | L1 | Status |
|---|---|---|---|
| Testnet | `testnet` | Sepolia | live |
| Mainnet (Prismo Glass) | `mainnet` | Ethereum | live (2026-10-07) |

Set `NETWORK` once (in `.env`, Helm values, or Terraform var); the templates load `configs/networks/<NETWORK>.env` for chain IDs, first block, contract addresses, and DNS.

---

## Quick Links

| I want to… | Go to |
|---|---|
| Understand the architecture and trust model | [docs/00-overview.md](docs/00-overview.md) |
| Pick a node type to run | [docs/00-overview.md#node-roles](docs/00-overview.md#node-roles) |
| Check hardware requirements | [docs/01-hardware.md](docs/01-hardware.md) |
| Get chain config / contract addresses | [docs/02-network-config.md](docs/02-network-config.md) |
| Use a snapshot to skip historical sync | [docs/03-snapshots.md](docs/03-snapshots.md) |
| Harden my node | [docs/04-security.md](docs/04-security.md) |
| Troubleshoot | [docs/troubleshooting.md](docs/troubleshooting.md) |
| Connect my app/wallet to a node | [docs/05-integration.md](docs/05-integration.md) |

## Node Roles (one-liner each)

| Role | What it does | Why run one |
|------|--------------|-------------|
| [RPC Node](docs/nodes/rpc-node.md) | Read-only `cdk-erigon` serving JSON-RPC | Decentralize user read path; lowest barrier |
| [Full Node](docs/nodes/full-node.md) | Re-executes every batch from L1 calldata | Independent state verification — detect bad state roots |
| [Watchtower](docs/nodes/watchtower.md) _(coming soon — binary not yet published)_ | Watches L1 contracts, alerts on misbehavior | Fraud detection while sequencer remains centralized |
| [Bridge Indexer](docs/nodes/bridge-indexer.md) | Indexes deposit/withdraw events L1↔L2 | Censorship-resistant withdrawals |

## Deploy Targets

Every node role ships docker-compose, systemd, and kubernetes configs. Cloud (Terraform + cloud-init) is complete for Azure (all roles) and for the RPC node on AWS/Hetzner; the AWS/Hetzner full-node, watchtower, and bridge-indexer dirs are README stubs for now.

```
deploy/
├── docker-compose/   # single-host containers, fastest start
├── systemd/          # bare-metal long-running, no container overhead
├── kubernetes/       # Helm values for k8s clusters
└── cloud/            # Terraform + cloud-init for AWS / Hetzner / Azure
```

Pick your target, then your node role:

```bash
cd deploy/docker-compose/rpc-node
cp .env.example .env       # NETWORK=testnet|mainnet + your L1 RPC

# Use scripts/compose.sh, not `docker compose` directly — the wrapper layers
# configs/networks/<NETWORK>.env under this .env before invoking Compose.
# Plain `docker compose up -d` renders every ${...} chain flag empty.
../../../scripts/compose.sh rpc-node up -d
```

## Key Network Facts

| Field | Testnet | Mainnet |
|---|---|---|
| L1 chain | Sepolia | Ethereum |
| L1 chain ID | `11155111` | `1` |
| L2 chain ID | `101001000` | `328` |
| L2 chain name (`--chain`) | `dynamic-glassnet` | `dynamic-glass` |
| L1 first block (RollupManager deploy) | `11147580` | `26136887` |
| Rollup manager (L1) | `0x920A41e4718639f0629407c9C14b0CaC9A266EF6` | `0xC2cBC231C486f7732473dD435a60f77e151d227d` |
| GER manager (L1) | `0x8D33cC75066Bcb7A1f584AB77a59Bb97F1bf37BF` | `0xf33FdfB61DAD1a19517DadceD33c6F39e5230C71` |
| Gas token (L1, 18-dec USDC wrapper) | `0xFB42879859F8d31089Ea6A9eBcA6996914aD9F9b` (test USDC) | `0xCB7B19F31EDda9e857899f99aFd732542079146f` (over real USDC) |
| Sequencer EOA (L2 coinbase, `--zkevm.address-sequencer`) | `0x691E2b6E666827BC87589cb0fA0BA772fd7Ea795` | `0x56Ea07AEf738B2aEa5073Bd9fd236cde08849783` |
| Trusted sequencer on L1 (sends `sequenceBatches`) | `0xd72FF0b50966AB4886fA59cbbfB55dafe21C1C08` | `0x12eda12aA4D0569Ef96029886E479fa7E9ae41d6` |
| Public RPC | `https://rpc.glassnet.prismo.network` | `https://rpc.prismo.network` |
| Block explorer | `https://explorer.glassnet.prismo.network` | `https://explorer.prismo.network` |
| Faucet (testnet USDC) | `https://faucet.glassnet.prismo.network` | n/a |

Full table in [docs/02-network-config.md](docs/02-network-config.md). Machine-readable in [`configs/networks/<network>.json`](configs/networks/).

## Repo Layout

```
.
├── docs/                # operator guides
├── deploy/              # ready-to-run manifests per node × target
├── configs/             # network-agnostic chain config + per-network values
│   └── networks/        # testnet.env / mainnet.env — single source of truth
├── scripts/             # verify snapshot, healthcheck, sync-progress, load-network-env
└── monitoring/          # Prometheus scrape + alert rules (Grafana dashboard: planned, see monitoring/README.md)
```

## Contributing

PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md). For protocol-level questions open an issue against the upstream Prismo core repo (link TBD).

## License

MIT — see [LICENSE](LICENSE).
