# Full Node — systemd

Same as the RPC-node systemd setup, but with `cdk-erigon` started in L1-only mode and a separate L1 stack matching the active `NETWORK`.

## Components

You'll run **three** systemd units on this host:

1. `geth.service` — L1 execution client (writes JWT secret at `/var/lib/l1/jwt.hex`); pass `${L1_NETWORK_FLAG}` (= `--sepolia` or `--mainnet`).
2. `lighthouse.service` — L1 consensus client (uses same JWT); set `--network=${L1_CHAIN_NAME}`.
3. `cdk-erigon.service` — Prismo full node. **Blocked upstream on the pinned `v2.61.24`:** the L1-only sync switch (`--zkevm.l1-sync-start-block`) panics `"you cannot launch in l1 sync mode as an RPC node"` unless `CDK_ERIGON_SEQUENCER=1`, which would make this process act as the trusted sequencer — wrong for this role. See the `KNOWN BLOCKER` note in [`../../docker-compose/full-node/docker-compose.yml`](../../docker-compose/full-node/docker-compose.yml). When it can run, the flag deltas vs the RPC unit are:
   - `--zkevm.l1-rpc-url=http://127.0.0.1:8645` (your local geth)
   - `--zkevm.l1-sync-start-block=${L1_FIRST_BLOCK}` (the real L1-recovery switch; `zkevm.sync-from-l1-only` does not exist on this binary)
   - `--zkevm.l2-datastreamer-url=${DATASTREAM_HOST}:${DATASTREAM_PORT}` (must be non-empty; empty panics `Flag not set: zkevm.l2-datastreamer-url`)
   - `--zkevm.l2-sequencer-rpc-url=${SEQUENCER_RPC_URL}` (hard-required at startup)
   - leave `zkevm.l1-contract-address-check` at `false` (on-chain address getters panic on the fork-12 RollupManager)

Reuse [`../rpc-node/cdk-erigon.service`](../rpc-node/cdk-erigon.service) and adjust the `ExecStart` flags. A fully scripted installer is **TODO**.

## L1 install reference

Use the official packages: `ethereum/client-go` (PPA on Ubuntu) and `lighthouse` Debian packages from sigp. Their unit files are upstream. Pass `${L1_NETWORK_FLAG}` from `/etc/prismo/network.env` so the same unit serves both testnet and mainnet hosts.

## Switching networks

Stop all three units, re-run the rpc-node `install.sh` with the new `NETWORK=`, wipe data dirs, restart.

## Why it's not yet auto-installed

L1 install scripts diverge by distro and we'd rather not maintain three copies. Contributions for Ubuntu 22.04 / 24.04 + Debian 12 welcome.
