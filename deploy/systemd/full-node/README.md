# Full Node — systemd

Same as the RPC-node systemd setup, but with `cdk-erigon` started in L1-only mode and a separate L1 stack matching the active `NETWORK`.

## Components

You'll run **three** systemd units on this host:

1. `geth.service` — L1 execution client (writes JWT secret at `/var/lib/l1/jwt.hex`); pass `${L1_NETWORK_FLAG}` (= `--sepolia` or `--mainnet`).
2. `lighthouse.service` — L1 consensus client (uses same JWT); set `--network=${L1_CHAIN_NAME}`.
3. `cdk-erigon.service` — Prismo full node, with these flag overrides vs the RPC unit:
   - `--zkevm.l1-rpc-url=http://127.0.0.1:8645` (your local geth)
   - `--zkevm.l2-datastreamer-url=` (empty)
   - `--zkevm.sync-from-l1-only=true`
   - `--zkevm.l1-contract-address-check=true`

Reuse [`../rpc-node/cdk-erigon.service`](../rpc-node/cdk-erigon.service) and adjust the `ExecStart` flags. A fully scripted installer is **TODO**.

## L1 install reference

Use the official packages: `ethereum/client-go` (PPA on Ubuntu) and `lighthouse` Debian packages from sigp. Their unit files are upstream. Pass `${L1_NETWORK_FLAG}` from `/etc/prismo/network.env` so the same unit serves both testnet and mainnet hosts.

## Switching networks

Stop all three units, re-run the rpc-node `install.sh` with the new `NETWORK=`, wipe data dirs, restart.

## Why it's not yet auto-installed

L1 install scripts diverge by distro and we'd rather not maintain three copies. Contributions for Ubuntu 22.04 / 24.04 + Debian 12 welcome.
