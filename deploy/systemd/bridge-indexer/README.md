# Bridge Indexer — systemd

`zkevm-bridge-service` runs fine as a static binary. Pair with locally installed Postgres or external managed Postgres. Single unit file works for testnet or mainnet — switch via `NETWORK=`.

## Quick install

```bash
NETWORK="${NETWORK:-testnet}"

# Postgres
sudo apt-get install -y postgresql-16
sudo -u postgres createuser bridge
sudo -u postgres createdb -O bridge bridge
sudo -u postgres psql -c "ALTER USER bridge WITH PASSWORD '<set-strong>';"

# Bridge service
sudo useradd --system --home /var/lib/zkevm-bridge --shell /usr/sbin/nologin zkbridge
sudo install -d -o zkbridge -g zkbridge /var/lib/zkevm-bridge /etc/zkevm-bridge
sudo curl -fSL <RELEASE_URL> -o /usr/local/bin/zkevm-bridge
sudo chmod +x /usr/local/bin/zkevm-bridge

# Canonical network values
sudo install -m 0644 ../../../configs/networks/${NETWORK}.env /etc/zkevm-bridge/network.env

# Render config.toml from the env-templated source in deploy/docker-compose/bridge-indexer/config.toml.
# `envsubst` works if you load network.env + your operator env first.
set -a; . /etc/zkevm-bridge/network.env; . /etc/zkevm-bridge/env; set +a
envsubst < ../../docker-compose/bridge-indexer/config.toml | sudo tee /etc/zkevm-bridge/config.toml
```

## Unit file

```ini
[Unit]
Description=Prismo bridge indexer
After=network-online.target postgresql.service
Requires=postgresql.service

[Service]
User=zkbridge
EnvironmentFile=/etc/zkevm-bridge/network.env
EnvironmentFile=/etc/zkevm-bridge/env
ExecStart=/usr/local/bin/zkevm-bridge run --cfg=/etc/zkevm-bridge/config.toml
Restart=on-failure
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
ReadWritePaths=/var/lib/zkevm-bridge

[Install]
WantedBy=multi-user.target
```

Save as `/etc/systemd/system/zkevm-bridge.service`, then:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now zkevm-bridge
```
