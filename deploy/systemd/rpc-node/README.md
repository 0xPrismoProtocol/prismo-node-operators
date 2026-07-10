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

```bash
sudo systemctl stop cdk-erigon
sudo curl -fSL https://github.com/0xPolygonHermez/cdk-erigon/releases/download/<NEW_VERSION>/cdk-erigon-linux-amd64 -o /usr/local/bin/cdk-erigon
sudo chmod +x /usr/local/bin/cdk-erigon
sudo systemctl start cdk-erigon
```

Read upstream changelog before bumping major versions. Test on testnet before rolling to mainnet.
