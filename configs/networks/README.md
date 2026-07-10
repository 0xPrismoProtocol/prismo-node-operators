# Networks

Per-network canonical values. Pick one with `NETWORK=testnet` or `NETWORK=mainnet`.

| File | Purpose |
|---|---|
| `testnet.env` | Shell-sourceable testnet values (Sepolia L1, chain `101001000`) |
| `testnet.json` | Same data, machine-readable |
| `mainnet.env` | Shell-sourceable mainnet values (Ethereum L1, all `TBD` until deployed) |
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

## Mainnet placeholders

`mainnet.env` ships with `TBD` for chain ID, first block, and every contract address. Populate **after** the mainnet deploy step (the Prismo core team manages contract deployment) and verify SHA-256 of any chainspec/genesis files.
