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
| Snapshots | `https://snapshots.glassnet.prismo.network` | `https://snapshots.prismo.network` (not yet published) | See [03-snapshots.md](03-snapshots.md) |

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

1. **Legacy (type-0) transactions only.** Fork-12 `batchL2Data` has no typed-transaction encoding, so the sequencer rejects EIP-1559 (type-2) and EIP-2930 (type-1) transactions (`unsupported transaction type`). The reference RPC tier runs a Prismo build of cdk-erigon that hides EIP-1559 from clients (no `baseFeePerGas` in headers, `eth_feeHistory` returns an error) so default wallets build type-0 automatically. **The upstream `ghcr.io/0xpolygon/cdk-erigon:v2.61.24` image this repo pins syncs and executes identically, but still advertises EIP-1559** — wallets pointed at *your* node will build type-2 transactions and have them rejected unless they pin `type: 0`. Tell your users, or front your node with a proxy that strips `baseFeePerGas` and fails `eth_feeHistory`. A public build of the Prismo image is planned; this file will be updated when it exists.
2. **Gas price floor: 816 gwei** (`zkevm.reject-low-gas-price-transactions` is on; `default-gas-price` = `max-gas-price` = `816000000000`). In 18-decimal USDC that is ≈0.017 USDC for a 21,000-gas transfer. `eth_gasPrice` on any node returns the right value; do not hardcode lower.
3. **Settlement is not yet enabled.** No `sequenceBatches` / `verifyBatches` transactions are posted to L1 yet (the core team is enabling this post-launch). Consequences for operators: `zkevm_virtualBatchNumber` stays at `1` and `zkevm_verifiedBatchNumber` at `0` on every node (expected, not a fault); the watchtower's `PrismoSequencerSilent` / `PrismoVerifierSilent` alerts fire permanently; bridge withdrawals L2→L1 cannot be claimed; and a full node in L1-only mode has nothing to derive from (that mode is also blocked upstream — see [nodes/full-node.md](nodes/full-node.md)). The trusted head streamed over the datastream is the only tier today.
4. **The gas token is a wrapper, not raw USDC.** `--zkevm.l1-matic-contract-address` must be the 18-decimal `USDC18Wrapper` (`0xCB7B19F3…`), never canonical 6-decimal USDC — registering raw USDC breaks gas accounting by 10¹².

Operationally: `rpc.prismo.network` serves HTTPS on 443 only (plain `http://` is refused), and the `debug`/`trace` namespaces are not exposed on the reference tier.

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
