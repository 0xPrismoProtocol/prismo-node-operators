# RPC Node — systemd

Bare-metal install. No containers. Same unit file works for testnet and mainnet — the network is selected at install time.

## Steps

```bash
cd deploy/systemd/rpc-node
NETWORK=testnet sudo bash install.sh         # or NETWORK=mainnet
sudo $EDITOR /etc/prismo/env                 # set L1_RPC_URL
sudo systemctl enable --now cdk-erigon
journalctl -u cdk-erigon -f
```

## Files placed

| Path | Owner | Purpose |
|---|---|---|
| `/usr/local/bin/cdk-erigon` | root | binary |
| `/etc/systemd/system/cdk-erigon.service` | root | unit |
| `/etc/prismo/chain-config.yaml` | root | network-agnostic chain config |
| `/etc/prismo/network.env` | root | canonical per-network values (chain IDs, contracts) |
| `/etc/prismo/env` | `root:prismo` 0640 | operator-editable env (L1_RPC_URL, NETWORK) |
| `/var/lib/prismo/data` | prismo | data dir |

`cdk-erigon.service` loads `network.env` first, then `env` second (so operator overrides win).

## Switching networks

```bash
sudo systemctl stop cdk-erigon
NETWORK=mainnet sudo bash install.sh         # rewrites /etc/prismo/network.env
sudo $EDITOR /etc/prismo/env                 # update L1_RPC_URL to a mainnet endpoint
# Optional: wipe data dir if you don't want stale testnet state
# sudo rm -rf /var/lib/prismo/data && sudo install -d -o prismo -g prismo /var/lib/prismo/data
sudo systemctl start cdk-erigon
```

## Updating

Bump the pinned version and **re-run the installer** — it re-extracts the
matching musl loader + libstdc++ for the new binary's ABI. A bare binary swap
would leave the previous version's runtime in `/usr/local/lib/cdk-erigon` (the
unit pins `LD_LIBRARY_PATH` there). No standalone release binaries are published
for cdk-erigon — the binary always comes from the pinned `ghcr.io/0xprismoprotocol/cdk-erigon`
image (from `0xpolygon`, **not** `0xPolygonHermez`). Pass the new version's index
digest so the install stays digest-pinned:

```bash
sudo systemctl stop cdk-erigon
# Get the digest: docker buildx imagetools inspect ghcr.io/0xprismoprotocol/cdk-erigon:<NEW_VERSION>
CDK_VERSION=<NEW_VERSION> CDK_DIGEST=sha256:<...> NETWORK=testnet sudo bash install.sh   # or NETWORK=mainnet
sudo systemctl start cdk-erigon
```

`install.sh` preserves your `/etc/prismo/env` on re-run, so only the binary,
libs, and unit are refreshed. Read the upstream changelog before bumping major
versions, and test on testnet before rolling to mainnet.
