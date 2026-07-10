# Watchtower — systemd

The unit file is provided. The binary `prismo-watchtower` does not yet have a published Linux build — until then run the Docker Compose variant under `deploy/docker-compose/watchtower/`, or build from source (TODO link).

## Manual install (once binary published)

```bash
NETWORK="${NETWORK:-testnet}"

sudo useradd --system --home /var/lib/prismo-watchtower --shell /usr/sbin/nologin prismo-watchtower
sudo install -d -o prismo-watchtower -g prismo-watchtower /var/lib/prismo-watchtower /etc/prismo-watchtower
sudo curl -fSL <BINARY_URL> -o /usr/local/bin/prismo-watchtower
sudo chmod +x /usr/local/bin/prismo-watchtower

# config.yaml — copy from deploy/docker-compose/watchtower/config.yaml (env-templated)
sudo cp config.yaml /etc/prismo-watchtower/config.yaml

# Canonical network values
sudo install -m 0644 ../../../configs/networks/${NETWORK}.env /etc/prismo-watchtower/network.env

# Operator env: secrets + alert sinks
sudo tee /etc/prismo-watchtower/env >/dev/null <<EOF
NETWORK=${NETWORK}
L1_RPC_URL=https://your-l1-provider.example/your-key
L2_RPC_URL=http://127.0.0.1:8545
SLACK_WEBHOOK_URL=
DISCORD_WEBHOOK_URL=
EOF
sudo chmod 0640 /etc/prismo-watchtower/env
sudo chown root:prismo-watchtower /etc/prismo-watchtower/env

sudo install -m 0644 prismo-watchtower.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now prismo-watchtower
```

The unit must `EnvironmentFile=` both `/etc/prismo-watchtower/network.env` and `/etc/prismo-watchtower/env` (env wins).

## Switching networks

Stop the unit, copy a different `configs/networks/<NETWORK>.env` over `/etc/prismo-watchtower/network.env`, update `/etc/prismo-watchtower/env`'s `NETWORK=` line and any L1/L2 RPC URLs, restart.
