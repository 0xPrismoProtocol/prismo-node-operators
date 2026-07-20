# Overview

## What is Prismo

Prismo is a zk-rollup built with **Polygon CDK Erigon**. L2 transactions are batched, posted to L1, and validity-proven by a SNARK. The L2 has its own ERC-20 gas token (USDC). The same architecture runs on testnet (settling to Sepolia) and mainnet (settling to Ethereum) — operator manifests in this repo accept either via the `NETWORK` variable.

| Network | L1 | Status |
|---|---|---|
| Testnet | Sepolia | live |
| Mainnet | Ethereum | TBD |

Network-specific chain IDs and contract addresses live in [`configs/networks/`](../configs/networks/).

## Trust Model Today

| Component | Operated by | Risk if it misbehaves |
|---|---|---|
| Sequencer | Prismo core team | Censorship, tx reordering. **Cannot steal funds** — bad state roots get rejected by L1 verifier. |
| Aggregator + Prover | Prismo core team | Liveness only — if it stops, no new finalized batches. |
| L1 verifier contract | Immutable + admin multisig | Compromised admin could rotate verifier — watchtowers detect. |
| Bridge contract | Immutable + admin multisig | Compromised admin could pause bridge — funds remain claimable after upgrade timelock. |

Public node operators **do not** add cryptographic security to a zk-rollup the same way an L1 validator does. SNARK verification on L1 already guarantees state validity. Public operators add:

1. **Censorship resistance** — multiple RPC providers, multiple bridge indexers.
2. **Liveness witnesses** — independent state-verifying full nodes that scream if sequencer posts incorrect data.
3. **Fraud detection** — watchtowers comparing L1-derived state to aggregator submissions.
4. **Data redundancy** — independent block explorers, archive nodes.

The trust model is identical on testnet and mainnet. Mainnet raises the *stakes* of misbehavior; the controls are the same.

## Node Roles

### RPC Node — read-only
- **Binary**: `cdk-erigon`
- **Inputs**: L1 RPC (read batches/events), Sequencer data stream (port 6900)
- **Outputs**: JSON-RPC on `:8545`, WebSocket, metrics on `:9091`
- **What it does**: Streams blocks from sequencer, executes them locally, serves user `eth_*` calls.
- **Why run one**: Decentralizes the user read path. If the official RPC is rate-limited or down, your node keeps users online.
- **Hardware**: see [docs/01-hardware.md](01-hardware.md#per-node-role) — comfortable minimum 4 vCPU / 8 GB / 100 GB NVMe, sized for growth (the cloud Terraform modules default to a larger headroom tier). Re-evaluate for mainnet.

### Full Node — state verifier
- Same binary as RPC, configured to **re-execute every batch from L1 calldata**, not from the sequencer stream.
- **What it does**: Pulls batch data directly from L1, reconstructs L2 state, compares to L1-posted state root.
- **Why run one**: Independent state verification — this is *not* a consensus validator (a zk-rollup has none; validity comes from the SNARK). zkProof guarantees validity, but this node catches data-availability problems, sequencer bugs, or upgrade incidents.
- **Hardware**: see [docs/01-hardware.md](01-hardware.md#per-node-role) — same tier as RPC (4 vCPU / 8 GB / 100 GB NVMe minimum) plus reliable L1 archive access (Sepolia for testnet, Ethereum for mainnet).

### Watchtower — fraud detector
- **Binary**: lightweight Go service (this repo: `prismo-watchtower`).
- **What it does**: Subscribes to L1 events on the rollup contract (`SequenceBatches`, `VerifyBatches`). For each verified batch range, fetches the corresponding L2 state root from a full node and compares to the on-chain root.
- **Why run one**: First line of defense against verifier bugs, malicious upgrades, or data unavailability.
- **Hardware**: 2 vCPU, 4 GB RAM, 50 GB SSD. Plus an L2 full node it can query.

### Bridge Indexer — withdrawal infrastructure
- **Binary**: `zkevm-bridge-service` (Polygon upstream).
- **What it does**: Indexes `Bridge` contract events on both L1 and L2. Builds Merkle proofs that users need to **claim** withdrawals on L1.
- **Why run one**: If the official bridge UI/indexer is down or censoring, users still need to be able to claim their assets. Anyone can self-host.
- **Hardware**: 4 vCPU, 8 GB RAM, 200 GB SSD. Plus a Postgres DB.

## What this repo does NOT contain

- **Sequencer config** — single-instance, operated by Prismo core only.
- **Aggregator / prover config** — uses HSM-backed keys; permissioned today.
- **Genesis ceremony scripts** — chains are already live (testnet) or will be deployed by core (mainnet); you join an existing chain.
- **Token / faucet scripts** — see the upstream Prismo testnet repo.

## Recommended Path

1. Read [docs/01-hardware.md](01-hardware.md) and pick a node role you can host.
2. Decide which network to target (`testnet` for now, `mainnet` once live).
3. Read [docs/02-network-config.md](02-network-config.md) to confirm chain values are current.
4. Pick a deploy target under [`deploy/`](../deploy/) and follow its README.
5. Wire monitoring from [`monitoring/`](../monitoring/) into your stack.
6. Building an app, wallet, or service against a node you run? Read [docs/05-integration.md](05-integration.md) for connect snippets, RPC namespaces, and finality guidance.
7. Optional: register your node URL with the public registry (TBD).
