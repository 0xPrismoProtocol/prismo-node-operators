# Networks

Per-network canonical values. Pick one with `NETWORK=testnet` or `NETWORK=mainnet`.

| File | Purpose |
|---|---|
| `testnet.env` | Shell-sourceable testnet values (Sepolia L1, chain `101001000`) |
| `testnet.json` | Same data, machine-readable |
| `mainnet.env` | Shell-sourceable mainnet values (Ethereum L1, chain `328`, Prismo Glass) |
| `mainnet.json` | Same, machine-readable |

> Schema parity rule: every network file carries the SAME key set as `testnet.*` (the committed baseline).

## How deploy targets consume these

All four targets resolve `NETWORK` and load the matching `*.env` before building flags.

| Target | Where `NETWORK` is set | How values are loaded |
|---|---|---|
| Docker Compose | `.env` in each role's dir | Compose substitutes `${...}` from the active `.env` into `command:` flags |
| systemd | `/etc/prismo/env` | Unit reads `EnvironmentFile=`, `ExecStart=` interpolates |
| Kubernetes | Helm `values.yaml` `network:` field | Templates render contracts/IDs from selected network block |
| Terraform | `var.network` | `templatefile("cloud-init.yaml", { network = var.network, ... })` |

## Adding a new network

1. Create `<name>.env` and `<name>.json` here. Keep the same key set as the others.
2. Update `scripts/load-network-env.sh`'s allowlist.
3. Update tables in `docs/02-network-config.md`.
4. Open a PR — see `CONTRIBUTING.md`.

## Provenance

Mainnet values were populated 2026-10-09 from the chain-328 deploy output (RollupManager deployed at L1 block 26136887, rollup created at 26137324 on 2026-10-07) and cross-checked against the live reference RPC/sequencer configuration. Testnet values mirror the 2026-06-27 re-genesis. Always verify SHA-256 of the chain files against `configs/CHECKSUMS.txt`.
