# Security & Hardening

Operator-side checklist. Misconfigured RPC nodes have leaked admin keys, allowed RCE through `debug_*` endpoints, and exhausted disks via unfiltered traces.

## Network

| Port | Bind | Expose to public | Notes |
|------|------|---|---|
| `8545` (HTTP RPC) | `127.0.0.1` if behind reverse proxy | Behind TLS + rate-limit only | Never expose `admin_*`, `personal_*`, `miner_*` |
| `8546` (WS) | `127.0.0.1` | Behind TLS only | Same API surface as HTTP |
| `9091` (metrics) | `127.0.0.1` | No — local Prometheus only | |
| `30303` (P2P) | `0.0.0.0` | Yes if you want peers | Optional for cdk-erigon |
| `6900` (data stream client) | n/a | n/a — outbound only | TCP to sequencer |

### Secrets on the cloud paths (L1 RPC key)

On all three cloud modules, `L1_RPC_URL` — which usually carries a provider API key — is written from Terraform into instance **user-data** (`/etc/prismo/operator.env`) and is therefore stored in **Terraform state** and readable on the instance via **IMDS**. Marking the TF variable `sensitive = true` only masks CLI/plan output; it does **not** encrypt state or hide the rendered user-data. Anyone with read access to the state file or to instance metadata can read the key.

The Kubernetes chart already does this right: `L1_RPC_URL` is sourced from a `Secret` via `secretKeyRef` (see `deploy/kubernetes/chart/templates/statefulset.yaml`), so it never lands in a plaintext ConfigMap. For the cloud paths, prefer fetching the key **post-boot** from AWS SSM Parameter Store / Azure Key Vault / a Hetzner secret store (with an instance role / managed identity) instead of baking it into user-data. This refactor is tracked as a hardening follow-up.

### Reverse proxy (nginx)

This vhost ships as a ready-to-copy file at [`deploy/cloud/nginx/prismo.conf`](../deploy/cloud/nginx/prismo.conf) (the block below is the same content). `limit_req_zone` is only valid in the `http` context, not inside `server{}` — put this file at `/etc/nginx/conf.d/prismo.conf` (nginx's default `nginx.conf` already `include`s `conf.d/*.conf` from inside its `http{}` block, so a top-level directive in this file lands in the right context without you needing your own `http{}` wrapper). The directive placement is correct: verified with `nginx:stable` (1.30.3) that `nginx -t` passes on exactly this file **once the `ssl_certificate`/`ssl_certificate_key` files it references exist on disk**. Obtain the certs first (run certbot — see [TLS certificates (certbot)](#tls-certificates-certbot) below); until they are present, `nginx -t` fails with `cannot load certificate … No such file`, which is a missing-cert condition, not a config error.

```nginx
# /etc/nginx/conf.d/prismo.conf
limit_req_zone $binary_remote_addr zone=rpc:10m rate=20r/s;

server {
  listen 443 ssl;
  http2 on;
  server_name rpc.your-domain.example;

  ssl_certificate     /etc/letsencrypt/live/rpc.your-domain.example/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/rpc.your-domain.example/privkey.pem;

  limit_req zone=rpc burst=40 nodelay;

  location / {
    proxy_pass http://127.0.0.1:8545;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    client_max_body_size 1m;
    proxy_read_timeout 30s;
  }

  # WebSocket (cdk-erigon's :8546) — separate path since it's a different
  # upstream port than the HTTP RPC above.
  location /ws {
    proxy_pass http://127.0.0.1:8546;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_read_timeout 3600s;   # keep long-lived subscriptions open
  }
}
```

### TLS certificates (certbot)

Obtain the Let's Encrypt certs the vhost references **before** starting nginx — `nginx -t` fails until they exist. The cloud-init templates install certbot but do not run it (your DNS A record must resolve to the host first):

```bash
# Point rpc.your-domain.example at this host's public IP, then:
sudo certbot --nginx -d rpc.your-domain.example
# Non-interactive / no vhost yet? Issue standalone and wire the paths in manually:
# sudo certbot certonly --standalone -d rpc.your-domain.example
```

Then copy the shipped vhost in and reload:

```bash
sudo cp /opt/prismo-node-operators/deploy/cloud/nginx/prismo.conf /etc/nginx/conf.d/prismo.conf
# edit server_name + the two ssl_certificate paths to your hostname
sudo nginx -t && sudo systemctl reload nginx
```

Add a JSON-RPC method allowlist using a small filter (e.g. [eth-rpc-proxy](https://github.com/grassrootseconomics/eth-rpc-proxy) or homemade): block `admin_*`, `personal_*`, `miner_*`, `txpool_*` (debug endpoints up to you).

## API surface

cdk-erigon flag (already in supplied configs):

```yaml
http.api: [eth, net, web3, txpool, zkevm]   # safe public default
# add 'debug', 'trace' only for private / archive endpoints
```

## Keys & secrets

Read-only nodes need **no signing keys**. If your node has a key file on disk, you have a misconfiguration — RPC, full nodes, watchtowers, and bridge indexers all run keyless.

The bridge indexer's Postgres DSN is the most sensitive secret in this repo. Keep it out of `docker-compose.yml`; use `.env` and chmod `0600`.

## OS hardening

- Run cdk-erigon as a non-root user (`prismo`, uid 10000 in our manifests).
- `systemd` unit ships with `ProtectSystem=strict`, `ProtectHome=yes`, `NoNewPrivileges=yes`, `PrivateTmp=yes`, `CapabilityBoundingSet=` (drop all).
- Keep host kernel + container runtime patched. `unattended-upgrades` on Debian/Ubuntu.

## Container hardening

`docker-compose.yml` files in this repo set:

```yaml
read_only: true
tmpfs:
  - /tmp
cap_drop: [ALL]
security_opt:
  - no-new-privileges:true
user: "10000:10000"
```

Do not run with `--privileged` or `--cap-add=NET_ADMIN` unless you know why.

## Monitoring (must-have alerts)

The `prismo-node` group in [`monitoring/alert-rules.yaml`](../monitoring/alert-rules.yaml) — every rule below is keyed on a metric cdk-erigon actually exposes on `:9091/debug/metrics/prometheus` (verified against a live node):

- `PrismoNodeStalled` — execution stage hasn't advanced in 10 min (`increase(sync{stage="execution"}[10m]) == 0`)
- `PrismoNodeL1SyncStalled` — L1 syncer hasn't advanced in 15 min (throttled/dead L1 RPC)
- `PrismoNodeRPCErrors` — `rate(rpc_failure[5m]) > 1`
- `PrismoNodeScrapeDown` — Prometheus can't reach `:9091` for 5 min (`up == 0`)
- `PrismoNodeRestarted` — the cdk-erigon process restarted (crashloop signal)

Disk-space alerting is intentionally **not** in this group: cdk-erigon exposes no filesystem-free metric, so run `node_exporter` alongside and alert on `node_filesystem_avail_bytes` for the datadir mount. The `prismo-watchtower` and `prismo-bridge` groups in the same file are aspirational (they reference metrics only a running watchtower/bridge emits) and will not fire on an RPC-only deployment.

## Updates

This repo pins the cdk-erigon image to a specific version **tag** (`v2.61.24`) **and** its index digest (`@sha256:…`) across every deploy target — compose, systemd (`install.sh`), and the k8s chart — so a re-pushed tag can never silently change what runs. Never use `:latest`. When upgrading:

1. Read the upstream changelog (cdk-erigon, zkevm-bridge-service).
2. Test on **testnet first**, then a non-production mainnet node, before rolling production.
3. Snapshot your data dir before bumping major versions.

## Mainnet-specific extras

Once `NETWORK=mainnet` is in use, also:

- Run **at least one** independent watchtower per region you operate in.
- Move bridge-indexer Postgres to a managed instance with PITR backups.
- Subscribe `PrismoContractUpgrade` and `PrismoFraudDetected` alerts to a paging channel, not Slack.
- Treat the RPC node's `debug_*` namespace as off by default; require an internal-only auth boundary to enable.

## Reporting issues

Security issues → email security@prismo.example (placeholder). Do not file public issues for unpatched vulnerabilities.
