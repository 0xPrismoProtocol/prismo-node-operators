# Configs

Canonical chain configuration for public Prismo nodes — works for both **testnet** and **mainnet**.

| File | Purpose |
|---|---|
| `networks/testnet.env` / `testnet.json` | Testnet values (Sepolia L1, chain `101001000`) |
| `networks/mainnet.env` / `mainnet.json` | Mainnet values (Ethereum L1, chain `328`, Prismo Glass) |
| `chain-config.yaml` | Network-agnostic cdk-erigon flag set (HTTP, metrics, prune) |
| `dynamic-glassnet-allocs.json` / `-chainspec.json` / `-conf.json` | Testnet chain files — cdk-erigon dynamic-chain definition, chain-name-keyed |
| `dynamic-glass-allocs.json` / `-chainspec.json` / `-conf.json` | Mainnet chain files (chain name `dynamic-glass`) |
| `testnet/genesis.json` / `mainnet/genesis.json` | cdk-node-style genesis (root + accounts); informational, not read by cdk-erigon |
| `CHECKSUMS.txt` | SHA-256 of files in this directory |

## How it fits together

`chain-config.yaml` carries flags identical across networks. Per-network values (chain IDs, first block, contract addresses, datastream host) are injected as cdk-erigon CLI flags by each deploy target, sourced from `configs/networks/<NETWORK>.env`.

Pick a network with `NETWORK=testnet` (or `NETWORK=mainnet`) in your `.env` / Helm values / Terraform vars; the deploy template loads the matching file.

## Chain files (dynamic-\<chain\>-\*.json)

These **are committed** in this directory and checksummed in `CHECKSUMS.txt`. Testnet files mirror the 2026-06-27 USDC re-genesis (genesis root `0xc2d11ba9f21d1118d695a6462f9d2ee6cf809f18ca68900c0d55ef5d8375801d`); mainnet files mirror the 2026-10-07 Prismo Glass genesis (root `0x8d57491b40ebea2099f08f34739a780e0cce883253e1d5bd4f19b1728aa8b53f`), byte-identical to what the reference RPC tier runs:

```
configs/
├── dynamic-glassnet-allocs.json     # TESTNET — cdk-erigon dynamic-chain files;
├── dynamic-glassnet-conf.json       # MUST sit next to chain-config.yaml
├── dynamic-glassnet-chainspec.json  # (cdk-erigon resolves dynamic-<chain>-*.json
├── dynamic-glass-allocs.json        # MAINNET   relative to the --config file's
├── dynamic-glass-conf.json          #           directory)
├── dynamic-glass-chainspec.json
├── testnet/
│   └── genesis.json                 # cdk-node-style genesis; not read by cdk-erigon
└── mainnet/
    └── genesis.json                 # same, for Prismo Glass (13 accounts)
```

The files are chain-name-keyed (`dynamic-<L2_CHAIN_NAME>-*.json`), so both networks coexist flat in this same directory without subfolders. cdk-erigon's `--chain` flag must match `L2_CHAIN_NAME` for the active network (`dynamic-glassnet` / `dynamic-glass`). Full detail: [docs/02-network-config.md#genesis--allocations](../docs/02-network-config.md#genesis--allocations).

> Both `dynamic-*-conf.json` files are intentionally just `{"timestamp": 0}` — for these dynamic chains cdk-erigon reads chain parameters from `-chainspec.json` and initial state from `-allocs.json`; `-conf.json` only supplies the genesis L2 timestamp (`0`). They are **complete, not truncated** (SHA-256 pinned in `CHECKSUMS.txt`).

**Always verify the SHA-256 in `CHECKSUMS.txt` before using these files** (see Verifying below).

## Verifying

```bash
cd configs
sha256sum -c CHECKSUMS.txt
```

The pinned hashes are computed against the committed **LF** content, and the
repo ships a `.gitattributes` (`configs/** text eol=lf`) so a fresh clone keeps
them byte-exact on every platform. If you cloned with `core.autocrlf=true` (the
Git for Windows default) **before** `.gitattributes` landed, re-normalize first,
otherwise `sha256sum -c` fails on all entries with `\r`-mangled names/bodies:

```bash
git rm --cached -r configs && git checkout -- configs
```

Or verify a single file directly against the commit: `git show HEAD:configs/<file> | sha256sum`.
