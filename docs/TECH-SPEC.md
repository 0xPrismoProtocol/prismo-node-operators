# Prismo Operator Nodes — Technical Specification

**Status:** Draft · **Version:** 0.1 · **Date:** 2026-05-30
**Scope:** Non-sequencer node roles operated by external parties on the Prismo zkEVM (Polygon CDK Erigon rollup).
**Audience:** Node operators, integrators, and the Prismo core team reviewing the operator surface.

This document specifies *what* operator nodes are, the interfaces and data flows they depend on, their trust boundaries, and the requirements each role must meet. It is the design-level companion to the operational how-to guides in [`docs/nodes/`](nodes/). Where this spec and a node guide disagree, this spec is authoritative for design intent; the guides are authoritative for exact commands.

---

## 1. Goals and Non-Goals

### 1.1 Goals
- Define the four operator node roles (RPC, Full, Watchtower, Bridge Indexer) as a stable contract: inputs, outputs, ports, and external dependencies.
- Specify a single network-selection mechanism (`NETWORK`) so every role and deploy target runs testnet or mainnet from one variable.
- State the trust model precisely: what security operator nodes add, and what they explicitly do not.
- Define correctness, liveness, and security requirements per role, with measurable SLOs where they exist.

### 1.2 Non-Goals
- Sequencer, aggregator, and prover design — operated by Prismo core, permissioned, out of scope.
- Genesis / chain bring-up — operators join an existing chain.
- Token, faucet, and bridge-UI design — upstream Prismo testnet repo.
- Cryptographic protocol design (SNARK circuit, verifier) — inherited from Polygon CDK.

---

## 2. System Context

```
                         L1 (Sepolia testnet / Ethereum mainnet)
        ┌───────────────────────────────────────────────────────────────┐
        │  RollupManager  ·  GER Manager  ·  Bridge  ·  USDC gas token    │
        └───────────────────────────────────────────────────────────────┘
              ▲ batches/proofs        ▲ events            ▲ events
              │ (core only)           │                   │
   ┌──────────┴─────────┐            │                   │
   │ Sequencer/Aggregator│           │                   │
   │   (Prismo core)     │           │                   │
   └──────────┬─────────┘            │                   │
              │ datastream :6900     │                   │
              ▼                      │                   │
   ┌─────────────────┐   ┌───────────┴──────┐   ┌────────┴──────────┐
   │  RPC Node       │   │  Full Node       │   │  Bridge Indexer   │
   │  (stream-fed)   │   │  (L1-replay)     │   │  (event-indexed)  │
   └─────────────────┘   └────────┬─────────┘   └───────────────────┘
                                  │ zkevm_getBatchByNumber
                                  ▼
                          ┌───────────────┐
                          │  Watchtower   │ → alerts (Slack/Discord/webhook)
                          └───────────────┘
```

Every operator node depends on an **L1 RPC endpoint** on the network it follows. The RPC node additionally depends on the sequencer **datastream**; the watchtower additionally depends on a **full node**; the bridge indexer additionally depends on a **Postgres** instance.

---

## 3. Trust Model and Security Boundary

zkEVM validity is guaranteed on L1 by SNARK verification. Operator nodes therefore **do not** add cryptographic security the way an L1 validator does. They add four operational properties:

1. **Censorship resistance** — multiple independent RPC and bridge-indexer endpoints so no single provider gates user access.
2. **Liveness witnesses** — full nodes that independently reconstruct state from L1 and detect data-availability failures.
3. **Fraud detection** — watchtowers comparing L1-claimed state roots to independently computed roots.
4. **Data redundancy** — independent explorers/archives.

| Component | Operated by | Worst-case misbehavior | Operator-node mitigation |
|---|---|---|---|
| Sequencer | Core | Censor / reorder. Cannot steal — bad roots rejected by L1 verifier. | RPC + bridge-indexer redundancy |
| Aggregator + Prover | Core | Liveness halt only | Watchtower liveness alert |
| L1 verifier contract | Immutable + admin multisig | Admin rotates verifier | Watchtower upgrade alert |
| Bridge contract | Immutable + admin multisig | Admin pauses bridge | Bridge indexer keeps proofs claimable |

**Security boundary:** operator nodes are *read-only relative to consensus*. None sign blocks, hold sequencing keys, generate proofs, or submit state-changing protocol transactions. A fully compromised operator node can serve bad data to its own clients but **cannot** corrupt chain state or finality.

---

## 4. Network Selection

A single `NETWORK ∈ {testnet, mainnet}` variable selects all chain-specific values. Canonical per-network values are the single source of truth in [`configs/networks/<NETWORK>.{env,json}`](../configs/networks/). No chain ID, contract address, or first block is hardcoded in any deploy manifest.

| Field | Testnet | Mainnet |
|---|---|---|
| L1 chain | Sepolia (`11155111`) | Ethereum (`1`) |
| L2 chain ID | `101001000` | TBD |
| L2 chain name | `dynamic-glassnet` | TBD |
| L1 first block | `11147580` | TBD |
| Rollup manager (L1) | `0x920A41e4718639f0629407c9C14b0CaC9A266EF6` | TBD |
| Rollup Etrog (rollupID 1) | `0xFfA25304376eE1274ff6A348400C03f444F22B95` | TBD |
| GER manager (L1) | `0x8D33cC75066Bcb7A1f584AB77a59Bb97F1bf37BF` | TBD |
| Gas token USDC (L1) | `0xFB42879859F8d31089Ea6A9eBcA6996914aD9F9b` | TBD |
| Sequencer EOA (`--zkevm.address-sequencer`, L2 coinbase) | `0x691E2b6E666827BC87589cb0fA0BA772fd7Ea795` | TBD |
| Trusted sequencer on L1 (sends `sequenceBatches`) | `0xd72FF0b50966AB4886fA59cbbfB55dafe21C1C08` | TBD |
| Bridge L1 / L2 | `0xd7d4F6BFD45C3EaEFde6fAEc0920fBC7E5a71D0d` | TBD |
| Datastream | `datastream.glassnet.prismo.network:6900` (public, relay-fronted) | TBD |
| Trusted sequencer RPC (`SEQUENCER_RPC_URL`) | `https://sequencer.glassnet.prismo.network` | TBD |
| Datastream version | `2` | TBD |
| Rollup ID | `1` | TBD |

Loading rules per deploy target:
- **docker-compose / systemd:** [`scripts/load-network-env.sh`](../scripts/load-network-env.sh) / `EnvironmentFile=` — `network.env` loaded first, role `.env` second (role wins).
- **kubernetes:** Helm `networks.<NETWORK>` value block.
- **cloud:** Terraform `network` var, validated `testnet|mainnet`.

**Requirement N-1:** changing `NETWORK` and restarting MUST be sufficient to retarget a node. No other edit may be required for a fully-deployed mainnet.

---

## 5. Node Role Specifications

All roles run on the sizing in [`docs/01-hardware.md`](01-hardware.md) (testnet floor; mainnet to be re-evaluated). Binaries: `cdk-erigon` (RPC + Full), `prismo-watchtower` (Watchtower), `zkevm-bridge-service` (Bridge Indexer).

### 5.1 RPC Node

| Property | Value |
|---|---|
| Binary | `cdk-erigon` (read-only mode) |
| Inputs | Sequencer datastream `:6900` (TCP, outbound); L1 RPC (light reads) |
| Outputs | JSON-RPC `:8545`, WebSocket, Prometheus `:9091` |
| Exposed RPC namespaces | `eth, net, web3, txpool, zkevm` |
| State source | Sequencer stream (executed locally) |
| Keys held | None |

**Data flow:** subscribe to datastream → receive blocks → execute locally to build state → serve `eth_*`/`zkevm_*` reads. Does not sign, seal, order, or prove.

**Requirements:**
- **R-1 (correctness):** locally executed state root MUST match the sequencer-streamed block at every height; divergence is a halt-and-alert condition.
- **R-2 (security):** `admin_*`, `personal_*`, `miner_*`, `debug_*` (non-archive) namespaces MUST NOT be publicly exposed; cdk-erigon HTTP binds `127.0.0.1` behind a TLS/rate-limit proxy (see [`docs/04-security.md`](04-security.md)).
- **R-3 (mode):** default **unpruned** (matches the reference RPC tier, and required for snapshot restores — cdk-erigon refuses `--prune` changes on an existing DB). Pruning is an opt-in for fresh genesis syncs only; see `configs/chain-config.yaml`.
- **SLO:** lag ≤ a few hundred ms behind sequencer head under normal load; geographic lag (Asia/EU vs `us-east-1` datastream) ~150–250 ms is acceptable.

### 5.2 Full Node (state-verifying)

| Property | Value |
|---|---|
| Binary | `cdk-erigon` (L1-replay mode) |
| Inputs | **L1 RPC (heavy — batch calldata replay)**; optional datastream for head |
| Outputs | JSON-RPC `:8545`, `zkevm_getBatchByNumber`, metrics |
| State source | **L1 calldata** (reconstructed independently) |
| Keys held | None |

**Data flow:** pull batch data directly from L1 from `L1_FIRST_BLOCK` → reconstruct L2 state → compare reconstructed root to L1-posted root. This is the independent witness that backs watchtowers.

**Requirements:**
- **R-4:** state MUST be derived from L1 calldata, NOT trusted from the sequencer stream — that independence is the role's entire value.
- **R-5:** requires reliable L1 **archive-grade** access; self-hosting L1 is recommended (full nodes hammer L1 during catch-up and public providers rate-limit). See [`docs/01-hardware.md` §L1 Dependency](01-hardware.md).
- **R-6:** a snapshot-restored full node MUST NOT be used as the sole authority for a fraud declaration — corroborate with a from-genesis sync.

### 5.3 Watchtower

> **Status: not yet runnable** — the `prismo-watchtower` binary/image is unpublished (`ghcr.io/0xprismoprotocol/watchtower:0.1.0` is a placeholder that does not resolve). This section is a design contract, not a deployable role today.

| Property | Value |
|---|---|
| Binary | `prismo-watchtower` (Go service) |
| Inputs | L1 RPC (event subscription); L2 full-node RPC; alert webhook URL(s) |
| Outputs | Alerts (Slack/Discord/webhook/email); persisted event audit log |
| State source | L1 events + full-node queries |
| Keys held | None |

**Watched L1 events:**
- `SequenceBatches(uint64 numBatch)` → record `(batchNum, l1TxHash, l1Block)`.
- `VerifyBatches(uint64 numBatch, bytes32 stateRoot, address aggregator)` → query full node for state root at `numBatch`, compare to L1-claimed root, mismatch fires `PrismoFraudDetected`.
- `UpdateRollupManager*` / `Upgraded` / admin events → governance/upgrade alert.

**Severity routing (default):** `fraud_detected` → page · `upgrade` → page · `sequencer_silent` (no `SequenceBatches` in 4 h) → warn. Finality gate: `finality_blocks = 64` before treating an L1 event as final. Alert cooldown 300 s.

**Requirements:**
- **R-7 (authority):** the watchtower raises alarm only — it MUST NOT send transactions, slash, or challenge. Response is human/community.
- **R-8 (independence):** operators SHOULD run **≥2** watchtowers backed by **different** full nodes; a single watchtower on a buggy backend is a liability.
- **R-9 (false-positive discipline):** a fraud alert MUST be corroborated (full node fully synced past N, both sides past finality) before public disclosure. Lagging or snapshot-restored backends are the common false-positive sources.
- **R-10:** all observed events MUST be persisted — this is the incident audit log.

### 5.4 Bridge Indexer

| Property | Value |
|---|---|
| Binary | `zkevm-bridge-service` (Polygon upstream) |
| Inputs | L1 RPC + L2 RPC (Bridge contract events both sides); Postgres |
| Outputs | Bridge REST API (deposit/withdraw status, Merkle claim proofs) |
| State source | `Bridge` contract events on L1 and L2 |
| Keys held | None |

**Data flow:** index `Bridge` deposit/withdraw events on both layers → build Merkle proofs users need to **claim** withdrawals on L1.

**Requirements:**
- **R-11 (censorship resistance):** the indexer's purpose is that withdrawals remain claimable even if the official bridge UI/indexer is down or censoring — it MUST be self-hostable end-to-end from public inputs.
- **R-12:** requires a dedicated Postgres (co-located or external); proof correctness depends on a gap-free event index from `L1_FIRST_BLOCK`.
- **R-13:** bridge contract addresses come from `configs/networks/<NETWORK>.env` (populated for testnet since the 2026-06-27 re-genesis; TBD on mainnet) — the indexer MUST refuse to start with placeholder/`TBD` addresses rather than index against `0x0`.

---

## 6. Interfaces

### 6.1 Network ports
| Role | Port | Proto | Direction | Purpose |
|---|---|---|---|---|
| RPC / Full | 8545 | HTTP | inbound | JSON-RPC |
| RPC / Full | 8546 | WS | inbound | JSON-RPC subscriptions |
| RPC / Full | 9091 | HTTP | inbound | Prometheus metrics |
| RPC / Full | 6900 | TCP | outbound | sequencer datastream |
| Watchtower | — | — | outbound | L1 RPC + L2 RPC + webhooks |
| Bridge Indexer | 8080 | HTTP | inbound | bridge REST API |
| Bridge Indexer | 5432 | TCP | local | Postgres |

### 6.2 RPC contract (RPC / Full)
- Standard `eth_*`, `net_*`, `web3_*`, `txpool_*`.
- zkEVM extensions: `zkevm_verifiedBatchNumber`, `zkevm_getBatchByNumber`, `zkevm_batchNumber`, etc.
- Health probes: `eth_syncing` (false = synced), `eth_blockNumber`, `zkevm_verifiedBatchNumber`. Helper: [`scripts/healthcheck.sh`](../scripts/healthcheck.sh).

### 6.3 Config surface
- Network-agnostic chain config: [`configs/chain-config.yaml`](../configs/chain-config.yaml), integrity-checked via [`configs/CHECKSUMS.txt`](../configs/CHECKSUMS.txt), mounted at `/etc/prismo/`.
- Per-network values: [`configs/networks/<NETWORK>.{env,json}`](../configs/networks/).

---

## 7. Deployment Targets

Every role ships all four targets; the chosen target does not change the role's interface contract (§6).

| Target | Path | Use case |
|---|---|---|
| docker-compose | `deploy/docker-compose/<role>/` | single-host, fastest start |
| systemd | `deploy/systemd/<role>/` | bare-metal, no container overhead |
| kubernetes | `deploy/kubernetes/<role>/` | Helm values for clusters |
| cloud | `deploy/cloud/{aws,hetzner,azure}/<role>/` | Terraform + cloud-init |

**Requirement D-1:** a role's behavior MUST be identical across targets; only orchestration differs. The combined-L1 compose template selects `--sepolia`/`--mainnet` from `L1_NETWORK_FLAG` in the active network env.

---

## 8. Observability

- **Metrics:** Prometheus scrape on `:9091` (RPC/Full). Scrape config + alert rules in [`monitoring/`](../monitoring/).
- **Key alerts:** node sync lag, datastream disconnect, L1 RPC error rate, watchtower `PrismoFraudDetected`, watchtower `sequencer_silent`, disk-growth runway.
- **Snapshots:** historical sync skip via [`docs/03-snapshots.md`](03-snapshots.md); snapshots verified against `snapshots_index` + [`scripts/verify-snapshot.sh`](../scripts/verify-snapshot.sh). Snapshot-restored nodes carry the §5.2 R-6 / §5.3 R-9 caveat for fraud claims.

---

## 9. Open Items

- **Mainnet values:** all `TBD` in §4 populated only after mainnet contracts deploy.
- **Bridge addresses:** `0xd7d4F6BFD45C3EaEFde6fAEc0920fBC7E5a71D0d` (testnet, 2026-06-27 re-genesis); mainnet `TBD` — populate from its step 04 output.
- **Watchtower binary:** `ghcr.io/0xprismoprotocol/watchtower:0.1.0` is a placeholder; binary not yet open-sourced, so the image does not resolve yet.
- **Public registries:** RPC registry / node registry URLs are TBD.
- **Mainnet sizing:** §5 hardware is testnet floor; re-run capacity planning with mainnet load data.

---

## 10. References
- [`README.md`](../README.md) — entry point
- [`docs/00-overview.md`](00-overview.md) — architecture + trust model narrative
- [`docs/01-hardware.md`](01-hardware.md) — sizing
- [`docs/02-network-config.md`](02-network-config.md) — chain values
- [`docs/04-security.md`](04-security.md) — hardening
- [`docs/nodes/`](nodes/) — per-role operator guides
