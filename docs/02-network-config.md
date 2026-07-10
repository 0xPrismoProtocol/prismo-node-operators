# Network Configuration

> **Source of truth.** Per-network values live in [`configs/networks/`](../configs/networks/). Testnet values mirror the canonical chain config. If they drift, file an issue.

Every deploy target reads `NETWORK=testnet|mainnet` and pulls the matching `*.env` / `*.json`.

## Chain Identifiers

| Field | Testnet | Mainnet |
|---|---|---|
| L2 chain name (cdk-erigon `--chain` flag) | `dynamic-glassnet` | `TBD` |
| L2 chain ID | `101001000` | `TBD` |
| L1 chain | Sepolia | Ethereum |
| L1 chain ID | `11155111` | `1` |
| L1 first block (rollup genesis) | `11147580` | `TBD` |
| Datastream version | `2` | `2` |
| Rollup ID | `1` | `TBD` |

## L1 Contract Addresses

| Contract | Testnet (Sepolia) | Mainnet |
|---|---|---|
| Rollup manager / zkEVM (cdk-erigon `--zkevm.address-rollup`/`address-zkevm`) | `0x920A41e4718639f0629407c9C14b0CaC9A266EF6` | `TBD` |
| Rollup (PolygonZkEVMEtrog, rollupID 1) | `0xFfA25304376eE1274ff6A348400C03f444F22B95` | `TBD` |
| GER (Global Exit Root) Manager | `0x8D33cC75066Bcb7A1f584AB77a59Bb97F1bf37BF` | `TBD` |
| Gas Token (USDC ERC-20) | `0xFB42879859F8d31089Ea6A9eBcA6996914aD9F9b` | `TBD` |
| Sequencer EOA (cdk-erigon `--zkevm.address-sequencer`, L2 coinbase) | `0x691E2b6E666827BC87589cb0fA0BA772fd7Ea795` | `TBD` |
| Trusted sequencer on L1 (sends `sequenceBatches`; informational) | `0xd72FF0b50966AB4886fA59cbbfB55dafe21C1C08` | `TBD` |
| Admin EOA | `0x691E2b6E666827BC87589cb0fA0BA772fd7Ea795` | `TBD` |
| Bridge L1 | `0xd7d4F6BFD45C3EaEFde6fAEc0920fBC7E5a71D0d` | `TBD` |
| Bridge L2 | `0xd7d4F6BFD45C3EaEFde6fAEc0920fBC7E5a71D0d` | `TBD` |

Machine-readable copies: [`configs/networks/testnet.json`](../configs/networks/testnet.json), [`configs/networks/mainnet.json`](../configs/networks/mainnet.json).

## Endpoints

| Service | Testnet | Mainnet | Purpose |
|---|---|---|---|
| Public RPC | `https://rpc.glassnet.prismo.network` | `https://rpc.prismo.example` | Reference RPC, rate-limited |
| Public WS | `wss://rpc.glassnet.prismo.network` | `wss://rpc.prismo.example/ws` | Subscriptions — same hostname as RPC; the ALB routes on the `Upgrade: websocket` header (no `/ws` path) |
| Sequencer data stream | `datastream.glassnet.prismo.network:6900` | `datastream.mainnet.prismo.example:6900` | TCP, plain framing — relay-tier fronted, live |
| Trusted sequencer RPC | `https://sequencer.glassnet.prismo.network` | `TBD` | `SEQUENCER_RPC_URL` — head resolution (`zkevm_getLatestDataStreamBlock`) + tx forwarding; must be the sequencer, NOT the RPC tier |
| Bridge API | `https://bridge.glassnet.prismo.network` | `https://bridge.prismo.example` | Public bridge indexer |
| Block explorer | `https://explorer.glassnet.prismo.network` | `https://explorer.prismo.example` | Blockscout |
| Faucet | `https://faucet.glassnet.prismo.network` | n/a | Testnet USDC drip |
| Snapshots | `https://snapshots.glassnet.prismo.network` | `https://snapshots.prismo.example` | Weekly, live — see [03-snapshots.md](03-snapshots.md) |

> Mainnet `*.example` values are placeholders until mainnet exists.

## Genesis & Allocations

Per-network genesis files, mirrored from the 2026-06-27 USDC re-genesis (genesis root `0xc2d11ba9f21d1118d695a6462f9d2ee6cf809f18ca68900c0d55ef5d8375801d`):

```
configs/
├── dynamic-glassnet-allocs.json     # cdk-erigon dynamic-chain files — MUST sit
├── dynamic-glassnet-conf.json       # next to chain-config.yaml (cdk-erigon
├── dynamic-glassnet-chainspec.json  # resolves dynamic-<chain>-*.json relative
│                                    # to the --config file's directory)
└── testnet/
    └── genesis.json                 # cdk-node-style genesis (root + actions); not read by cdk-erigon
```

Mainnet: add `dynamic-<mainnet-chain-name>-*.json` alongside once deployed — the files are chain-name-keyed, so networks coexist flat.

Verify the SHA-256 in [`configs/CHECKSUMS.txt`](../configs/CHECKSUMS.txt) before using.

## Gas Settings

| Field | Testnet | Mainnet |
|---|---|---|
| Default gas price | `1_000_000_000` (1 gwei) | `TBD` |
| Max gas price | `0` (uncapped) | `TBD` |
| Gas-price factor | `0.0375` | `TBD` |

## Bootnodes (P2P, optional)

cdk-erigon does **not** require P2P peers — blocks come from the sequencer data stream and L1. There is no bootnode list to configure for any network in this repo.

## Mounting these into a node

All four deploy targets mount `configs/` into the container/process at `/etc/prismo/`:

```yaml
# docker-compose excerpt
volumes:
  - ../../../configs:/etc/prismo:ro
env_file:
  - ../../../configs/networks/${NETWORK}.env
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
