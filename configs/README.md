# Configs

Canonical chain configuration for public Prismo nodes — works for both **testnet** and **mainnet**.

| File | Purpose |
|---|---|
| `networks/testnet.env` / `testnet.json` | Testnet values (Sepolia L1, chain `101001000`) |
| `networks/mainnet.env` / `mainnet.json` | Mainnet values (Ethereum L1, all `TBD` until deploy) |
| `chain-config.yaml` | Network-agnostic cdk-erigon flag set (HTTP, metrics, prune) |
| `dynamic-glassnet-allocs.json` / `-chainspec.json` / `-conf.json` | Testnet chain files — cdk-erigon dynamic-chain definition, chain-name-keyed |
| `testnet/genesis.json` | cdk-node-style genesis (root + actions); informational, not read by cdk-erigon |
| `CHECKSUMS.txt` | SHA-256 of files in this directory |

## How it fits together

`chain-config.yaml` carries flags identical across networks. Per-network values (chain IDs, first block, contract addresses, datastream host) are injected as cdk-erigon CLI flags by each deploy target, sourced from `configs/networks/<NETWORK>.env`.

Pick a network with `NETWORK=testnet` (or `NETWORK=mainnet`) in your `.env` / Helm values / Terraform vars; the deploy template loads the matching file.

## Chain files (dynamic-\<chain\>-\*.json)

These **are committed** in this directory, mirrored from the 2026-06-27 USDC re-genesis (genesis root `0xc2d11ba9f21d1118d695a6462f9d2ee6cf809f18ca68900c0d55ef5d8375801d`) and checksummed in `CHECKSUMS.txt`:

```
configs/
├── dynamic-glassnet-allocs.json     # cdk-erigon dynamic-chain files — MUST sit
├── dynamic-glassnet-conf.json       # next to chain-config.yaml (cdk-erigon
├── dynamic-glassnet-chainspec.json  # resolves dynamic-<chain>-*.json relative
│                                    # to the --config file's directory)
└── testnet/
    └── genesis.json                 # cdk-node-style genesis; not read by cdk-erigon
```

The files are chain-name-keyed (`dynamic-<L2_CHAIN_NAME>-*.json`), so multiple networks coexist flat in this same directory without subfolders — mainnet's `dynamic-<mainnet-chain-name>-*.json` files will be added alongside once mainnet deploys. cdk-erigon's `--chain` flag must match `L2_CHAIN_NAME` for the active network. Full detail: [docs/02-network-config.md#genesis--allocations](../docs/02-network-config.md#genesis--allocations).

**Always verify the SHA-256 in `CHECKSUMS.txt` before using these files** (see Verifying below).

## Verifying

```bash
cd configs
sha256sum -c CHECKSUMS.txt
```
