# Network Configuration

> **Source of truth.** Per-network values live in [`configs/networks/`](../configs/networks/). Both networks mirror the canonical chain config (mainnet populated 2026-10-09 from the 2026-10-07 deploy output). If they drift, file an issue.

Every deploy target reads `NETWORK=testnet|mainnet` and pulls the matching `*.env` / `*.json`.

## Chain Identifiers

| Field | Testnet | Mainnet |
|---|---|---|
| Display name | Glassnet (testnet) | Prismo Glass |
| L2 chain name (cdk-erigon `--chain` flag) | `dynamic-glassnet` | `dynamic-glass` |
| L2 chain ID | `101001000` | `328` |
| L1 chain | Sepolia | Ethereum |
| L1 chain ID | `11155111` | `1` |
| L1 first block (RollupManager deploy; `--zkevm.l1-first-block`) | `11147580` | `26136887` |
| L1 createRollup block (informational) | `11147585` | `26137324` |
| Genesis root | `0xc2d11ba9…5801d` | `0x8d57491b40ebea2099f08f34739a780e0cce883253e1d5bd4f19b1728aa8b53f` |
| Fork ID | `12` | `12` |
| Datastream version | `2` | `2` |
| Rollup ID | `1` | `1` |

## L1 Contract Addresses

| Contract | Testnet (Sepolia) | Mainnet |
|---|---|---|
| Rollup manager / zkEVM (cdk-erigon `--zkevm.address-rollup`/`address-zkevm`) | `0x920A41e4718639f0629407c9C14b0CaC9A266EF6` | `0xC2cBC231C486f7732473dD435a60f77e151d227d` |
| Rollup (PolygonZkEVMEtrog, rollupID 1) | `0xFfA25304376eE1274ff6A348400C03f444F22B95` | `0x261ECc4303b184F08bB6bDb43d653Ba4B65Ac956` |
| GER (Global Exit Root) Manager | `0x8D33cC75066Bcb7A1f584AB77a59Bb97F1bf37BF` | `0xf33FdfB61DAD1a19517DadceD33c6F39e5230C71` |
| Gas Token (18-decimal `USDC18Wrapper`; `--zkevm.l1-matic-contract-address`) | `0xFB42879859F8d31089Ea6A9eBcA6996914aD9F9b` (over open-mint test USDC) | `0xCB7B19F31EDda9e857899f99aFd732542079146f` (over canonical USDC `0xA0b86991…`) |
| Sequencer EOA (cdk-erigon `--zkevm.address-sequencer`, L2 coinbase) | `0x691E2b6E666827BC87589cb0fA0BA772fd7Ea795` | `0x56Ea07AEf738B2aEa5073Bd9fd236cde08849783` |
| Trusted sequencer on L1 (sends `sequenceBatches`; informational) | `0xd72FF0b50966AB4886fA59cbbfB55dafe21C1C08` | `0x12eda12aA4D0569Ef96029886E479fa7E9ae41d6` |
| Admin EOA | `0x691E2b6E666827BC87589cb0fA0BA772fd7Ea795` | `0x56Ea07AEf738B2aEa5073Bd9fd236cde08849783` |
| Bridge L1 | `0xd7d4F6BFD45C3EaEFde6fAEc0920fBC7E5a71D0d` | `0xB6F289768b02dB5983E41D2BeA04E23e356fEbA4` |
| Bridge L2 | `0xd7d4F6BFD45C3EaEFde6fAEc0920fBC7E5a71D0d` | `0xB6F289768b02dB5983E41D2BeA04E23e356fEbA4` |
| L2 GER predeploy (informational) | `0xa40d5f56745a118d0906a34e69aec8c0db1cb8fa` | `0xa40d5f56745a118d0906a34e69aec8c0db1cb8fa` |

Machine-readable copies: [`configs/networks/testnet.json`](../configs/networks/testnet.json), [`configs/networks/mainnet.json`](../configs/networks/mainnet.json).

## Endpoints

| Service | Testnet | Mainnet | Purpose |
|---|---|---|---|
| Public RPC | `https://rpc.glassnet.prismo.network` | `https://rpc.prismo.network` | Reference RPC, rate-limited |
| Public WS | `wss://rpc.glassnet.prismo.network` | `wss://rpc.prismo.network` | Subscriptions — same hostname as RPC; the ALB routes on the `Upgrade: websocket` header (no `/ws` path) |
| Sequencer data stream | `datastream.glassnet.prismo.network:6900` | `datastream.prismo.network:6900` | TCP, plain framing — relay-tier fronted. Check: `nc -z <host> 6900` |
| Trusted sequencer RPC | `https://sequencer.glassnet.prismo.network` | `https://sequencer.prismo.network` | `SEQUENCER_RPC_URL` — head resolution (`zkevm_getLatestDataStreamBlock`) + tx forwarding; must be the sequencer, NOT the RPC tier |
| Bridge API | `https://bridge.glassnet.prismo.network` | `https://bridge.prismo.network` | Public bridge indexer |
| Block explorer | `https://explorer.glassnet.prismo.network` | `https://explorer.prismo.network` | Blockscout |
| Faucet | `https://faucet.glassnet.prismo.network` | n/a | Testnet USDC drip; mainnet gas is real USDC bridged from Ethereum |
| Snapshots | `https://snapshots.glassnet.prismo.network` | `https://snapshots.prismo.network` | **Withdrawn 2026-10-10 — sync from genesis**; see [03-snapshots.md](03-snapshots.md) |

## Genesis & Allocations

Per-network chain files, chain-name-keyed so both networks coexist flat in `configs/`:

```
configs/
├── dynamic-glassnet-allocs.json     # TESTNET  (2026-06-27 re-genesis, root 0xc2d11ba9…5801d)
├── dynamic-glassnet-conf.json
├── dynamic-glassnet-chainspec.json
├── dynamic-glass-allocs.json        # MAINNET  (2026-10-07 genesis, root 0x8d57491b…8b53f)
├── dynamic-glass-conf.json          #   byte-identical to the reference RPC tier's files
├── dynamic-glass-chainspec.json
├── testnet/genesis.json             # cdk-node-style genesis (root + accounts); not read by cdk-erigon
└── mainnet/genesis.json
```

The three `dynamic-<chain>-*.json` files MUST sit next to `chain-config.yaml` — cdk-erigon resolves them relative to the `--config` file's directory, by the name passed to `--chain`.

**Mainnet genesis contents (13 accounts).** Beyond the standard CDK system contracts (bridge + GER predeploys, ProxyAdmin, timelock, deployer accounts), the Prismo Glass genesis contains two Prismo-specific entries you should know exist:

| Account | What it is |
|---|---|
| `0x505249534d4f0000000000000000000000000000` ("PRISMO" in ASCII) | **PrismoManifesto** NFT contract, deployed at genesis (11,347 bytes of code, verified on the explorer) |
| `0x4eCBDc85d6A0Fef7B83d49cfC6700547D632Add7` | **Genesis prefund of 1,000 USDC (18-dec units)** to the Manifesto owner. This balance was minted at genesis and is **not backed by USDC locked in the L1 bridge**. It is immaterial while settlement is disabled (nothing can be withdrawn), and the core team has committed to either backing it on L1 or publishing it as an operator liability before enabling settlement. |

Verify the SHA-256 in [`configs/CHECKSUMS.txt`](../configs/CHECKSUMS.txt) before using.

## Mainnet facts operators must know

Prismo Glass (chain 328) went live on 2026-10-07. It is a fork-12 CDK Erigon chain like testnet, but four things differ from what a generic EVM operator expects:

1. **Legacy (type-0) transactions only.** Fork-12 `batchL2Data` has no typed-transaction encoding, so the sequencer rejects EIP-1559 (type-2) and EIP-2930 (type-1) transactions (`unsupported transaction type`). This repo therefore pins the **Prismo build** `ghcr.io/0xprismoprotocol/cdk-erigon:v2.61.24-legacyonly` (the same image the reference tier runs on both networks): its txpool rejects typed transactions up front, and its RPC layer hides EIP-1559 from clients (no `baseFeePerGas` in headers; `eth_feeHistory` / `eth_maxPriorityFeePerGas` return an error pointing at `eth_gasPrice`), so default wallets build type-0 automatically. Consensus is untouched: it syncs and executes identically to upstream `ghcr.io/0xpolygon/cdk-erigon:v2.61.24`, and datadirs/snapshots are interchangeable. Source (LGPL-3.0): [`0xPrismoProtocol/cdk-erigon`](https://github.com/0xPrismoProtocol/cdk-erigon), branch `prismo/v2.61.24-no-typed-tx`, commit `8157e15`; `cdk-erigon --version` on the image prints that commit. If you run upstream instead, wallets pointed at your node will build type-2 transactions and have them rejected unless they pin `type: 0`. On the launch-day chain (before the 2026-10 rebuild below) the base fee stayed in the consensus header, so served header fields did not re-hash to the stated block hash. On the rebuilt chain headers carry no base fee at all (15 fields, no `baseFeePerGas`, no `withdrawalsRoot`).
2. **Gas price floor: 816 gwei** (`zkevm.reject-low-gas-price-transactions` is on; `default-gas-price` = `max-gas-price` = `816000000000`). In 18-decimal USDC that is ≈0.017 USDC for a 21,000-gas transfer. `eth_gasPrice` on any node returns the right value; do not hardcode lower.
3. **Settlement is not yet enabled.** No `sequenceBatches` / `verifyBatches` transactions are posted to L1 yet (the core team is enabling this post-launch). Consequences for operators: `zkevm_virtualBatchNumber` stays at `1` and `zkevm_verifiedBatchNumber` at `0` on every node (expected, not a fault); the watchtower's `PrismoSequencerSilent` / `PrismoVerifierSilent` alerts fire permanently; bridge withdrawals L2→L1 cannot be claimed; and a full node in L1-only mode has nothing to derive from (that mode is also blocked upstream — see [nodes/full-node.md](nodes/full-node.md)). The trusted head streamed over the datastream is the only tier today.
4. **The gas token is a wrapper, not raw USDC.** `--zkevm.l1-matic-contract-address` must be the 18-decimal `USDC18Wrapper` (`0xCB7B19F3…`), never canonical 6-decimal USDC — registering raw USDC breaks gas accounting by 10¹².

Operationally: `rpc.prismo.network` serves HTTPS on 443 only (plain `http://` is refused), and the `debug`/`trace` namespaces are not exposed on the reference tier.

### 2026-10 chain rebuild (chain 328)

Glass was rebuilt from genesis so that it can be proven on Ethereum: London and Shanghai
are now at the zk sentinel in `dynamic-glass-chainspec.json`, as in Polygon's own zk
chainspec (`params/chainspecs/hermez.json` in cdk-erigon). L1 is unchanged and no user funds are affected.
Every genesis account and the prefund account's balance and nonce are unchanged. The one balance that differs
is the sequencer fee recipient's: it now holds the value the prover computes, 2,270,170 wei more than on the
launch-day chain, from the base fee the old chainspec burned.

- **Unchanged:** the genesis **state root** `0x8d57491b40ebea2099f08f34739a780e0cce883253e1d5bd4f19b1728aa8b53f`,
  every genesis account, and every transaction hash.
- **New:** the genesis **block hash** `0x1bc44609484ffb59932651ca78fd95e6117f5d7abdafba2064dbf4bc873b4e18`
  (it was `0x61b3070bb40b8ea563e6dd7974abbf721cdfb538a294c216682d9f97bffb5d59`). Every block hash changed, and the
  launch transactions now sit in different (lower) block numbers. Headers no longer carry `baseFeePerGas`.
- **To resync:** stop the node; delete its datadir; take this release (the Kubernetes chart carries the same
  updated chainspec); run `cd configs && sha256sum -c CHECKSUMS.txt`; start the node. It syncs from genesis.
  No published snapshot applies to the rebuilt chain.
- **Node image:** unchanged (`v2.61.24-legacyonly`). You only need the new chainspec, a datadir wipe, and a resync.
- **If you do not:** a node still on the old chainspec is expected to stop with a state-root or bad-block
  error when it reaches the first replayed transaction. Do not run the old chainspec.

### Glassnet restore (chain 101001000)

Glassnet was rebuilt so that it can be proven on Sepolia again: London and Shanghai are now at
the zk sentinel in `dynamic-glassnet-chainspec.json`, as in Polygon's own zk chainspecs.

- **Unchanged:** the genesis **state root** `0xc2d11ba9f21d1118d695a6462f9d2ee6cf809f18ca68900c0d55ef5d8375801d`,
  batches 1–134, every transaction hash and every balance (to within each sender's gas).
- **New:** the genesis **block hash** `0x3cf2dc5ffd062a4aac16288ad519f64a06a8c3a3b35261becb5ee5b29bf285b6`
  (it was `0xe9f5292e…a727`; confirmed by the 2026-10-28 rehearsal's genesis gate). Every block hash, and every
  block number from 157,382 on, changed; headers no longer carry `baseFeePerGas`.
- **To resync:** stop the node; delete its datadir; take this release; run
  `cd configs && sha256sum -c CHECKSUMS.txt`; start the node.
- **If you do not:** a node on the old chainspec stops with a state-root mismatch at the first
  replayed transaction. It does not fork silently.

## Gas Settings

| Field | Testnet | Mainnet |
|---|---|---|
| Default gas price | `1_000_000_000` (1 gwei) | `816_000_000_000` (816 gwei) |
| Max gas price | `0` (uncapped) | `816_000_000_000` |
| Gas-price factor | `0.0375` | `0.0375` |
| Reject low-gas-price txs | off | **on** |
| Transaction types accepted | legacy (type-0) only | legacy (type-0) only |

## Bootnodes (P2P, optional)

cdk-erigon does **not** require P2P peers — blocks come from the sequencer data stream and L1. There is no bootnode list to configure for any network in this repo.

## Mounting these into a node

All four deploy targets mount `configs/` into the container/process at `/etc/prismo/`:

```yaml
# docker-compose excerpt — NOTE: the compose files do NOT use `env_file:`.
# scripts/compose.sh sources configs/networks/${NETWORK}.env (then the role's
# .env) into the environment before invoking Compose, and the values reach the
# process via an `environment:` map. Always launch via the wrapper —
# `scripts/compose.sh rpc-node up -d` — not a bare `docker compose up`, or the
# ${...} flags render empty.
volumes:
  - ../../../configs:/etc/prismo:ro
environment:
  NETWORK:          ${NETWORK}
  L2_CHAIN_NAME:    ${L2_CHAIN_NAME}
  L2_CHAIN_ID:      ${L2_CHAIN_ID}
  L1_CHAIN_ID:      ${L1_CHAIN_ID}
  L1_FIRST_BLOCK:   ${L1_FIRST_BLOCK}
  # ...plus L1_RPC_URL and the other per-network keys
```

cdk-erigon flags then come from the active network env:

```
--chain=${L2_CHAIN_NAME}
--zkevm.l2-chain-id=${L2_CHAIN_ID}
--zkevm.l1-chain-id=${L1_CHAIN_ID}
--zkevm.l1-first-block=${L1_FIRST_BLOCK}
--zkevm.l1-rollup-id=${ROLLUP_ID}
--zkevm.l1-block-range=${L1_BLOCK_RANGE}
--zkevm.l1-rpc-url=${L1_RPC_URL}
--zkevm.address-rollup=${ROLLUP_CONTRACT}
--zkevm.address-zkevm=${ROLLUP_CONTRACT}
--zkevm.address-ger-manager=${GER_MANAGER}
--zkevm.l1-matic-contract-address=${GAS_TOKEN}
--zkevm.address-sequencer=${SEQUENCER_EOA}
--zkevm.address-admin=${ADMIN_EOA}
--zkevm.l2-datastreamer-url=${DATASTREAM_HOST}:${DATASTREAM_PORT}
--zkevm.datastream-version=${DATASTREAM_VERSION}
--zkevm.l2-sequencer-rpc-url=${SEQUENCER_RPC_URL}
```

`--zkevm.l2-sequencer-rpc-url` is not optional — cdk-erigon's RPC mode hard-requires it (panics on startup without it) and it must point at the **trusted sequencer's** RPC (`SEQUENCER_RPC_URL`), not the public RPC tier; see the `SEQUENCER_RPC_URL` note under [Endpoints](#endpoints) above.
