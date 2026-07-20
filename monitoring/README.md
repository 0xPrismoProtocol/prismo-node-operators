# Monitoring

Drop-in Prometheus + Alertmanager rules for any node role, on testnet or mainnet.

**Status (2026-07-08):** the `prismo-node` alert group is real and verified
against a live cdk-erigon v2.61.24 node — every expression in it references a
metric confirmed present in that node's own `/debug/metrics/prometheus`
output. The `prismo-watchtower` and `prismo-bridge` groups are aspirational:
the watchtower binary is still a placeholder image and the bridge-indexer's
actual `/metrics` output has not yet been captured against a live instance,
so those two groups will not fire on an RPC-only deployment. There is no
`grafana-dashboard.json` in this directory and no Grafana dashboard ships
with this repo today — the working, verified deliverable here is the
Prometheus scrape + alert config below, not a dashboard.

## Files

| File | Purpose |
|---|---|
| `prometheus.yml` | Scrape config for cdk-erigon, watchtower, bridge-indexer. Set `external_labels.network` per host. |
| `alert-rules.yaml` | Alert definitions — `prismo-node` group is real/verified (sync stall, L1-syncer stall, RPC errors, scrape-down, process restarts); `prismo-watchtower`/`prismo-bridge` groups are aspirational (see header comments in the file). Alerts include the `network` label so a single Alertmanager can route testnet vs mainnet differently. |
| `docker-compose.monitoring.yml` | Optional standalone Prometheus, wired to actually reach the node's loopback-bound metrics ports — see [Wiring](#wiring) below. |

## Network labelling

`prometheus.yml` ships with `external_labels.network: testnet`. Change to `mainnet` on mainnet hosts (or template per host with config-management). Every alert and metric will carry that label, so Alertmanager routes can be:

```yaml
route:
  routes:
    - matchers: [ network="mainnet", severity="critical" ]
      receiver: pagerduty-mainnet
    - matchers: [ network="testnet", severity="critical" ]
      receiver: slack-testnet-ops
```

## Wiring

### Docker Compose

The node compose files (`deploy/docker-compose/*/docker-compose.yml`) bind
their metrics ports to the host's loopback ONLY (e.g. `"127.0.0.1:9091:9091"`)
— deliberate, so metrics aren't reachable beyond the host without a reverse
proxy. That means a naive sibling Prometheus container on its own bridge
network (the default `docker compose up` topology) **cannot** reach them:
neither the container's own bridge-gateway IP nor `host.docker.internal` +
`extra_hosts: host-gateway` resolves to the host's loopback interface —
verified live, that combination scrapes as connection-refused on every
target.

Use the provided compose file instead, which runs Prometheus with
`network_mode: host` (Linux-only) so `127.0.0.1` inside the container really
is the host's loopback:

```bash
docker compose -f monitoring/docker-compose.monitoring.yml up -d
curl -s http://127.0.0.1:9090/api/v1/targets | jq   # confirm health: "up"
```

This was proven live against a running rpc-node: `prismo-cdk-erigon` came
back `health: "up"` with real series (e.g. `sync{stage="execution"}`)
queryable at `http://127.0.0.1:9090`.

Running Prometheus on Docker Desktop (Mac/Windows), where `network_mode:
host` isn't available? Run Prometheus directly on the host (bare-metal
install, see below) instead of in a container, or deliberately widen the
node's port bindings to `0.0.0.0` behind your own firewall — this repo does
not do that by default.

### Kubernetes

Use kube-prometheus-stack. The Helm `values.yaml` files in `deploy/kubernetes/*/` ship `monitoring.serviceMonitor.enabled: false` — flip it to `true` once the Prometheus Operator CRDs are installed in-cluster. Apply the alert rules as a `PrometheusRule` CRD with the same content. Set the `network` external label on the Prometheus instance per cluster (one cluster per network is the cleanest split).

### Bare-metal

```bash
sudo apt install -y prometheus
sudo cp prometheus.yml /etc/prometheus/prometheus.yml
sudo cp alert-rules.yaml /etc/prometheus/alert-rules.yaml
# Edit /etc/prometheus/prometheus.yml: set external_labels.network correctly for this host.
sudo systemctl restart prometheus
```

## Alertmanager routing recommendation

> **Delivery is bring-your-own.** This repo ships Prometheus only (`monitoring/docker-compose.monitoring.yml`) and `prometheus.yml` has no `alerting:` block, so the bundled rules **evaluate but are not delivered** anywhere. To get notifications, run your own Alertmanager and add an `alerting:` + `alertmanagers:` stanza to `prometheus.yml` (kube-prometheus-stack users already have one). The table below is the routing we recommend once Alertmanager is in place.

| Severity | Testnet | Mainnet |
|---|---|---|
| `critical` (fraud, contract upgrade, scrape-down) | Slack #your-ops-channel | PagerDuty / on-call page |
| `warning` (sync stall, L1-syncer stall, RPC errors) | Slack #your-ops-channel | Slack #your-ops-channel |
| `info` (process restart) | none required — log/dashboard only | none required — log/dashboard only |

`PrismoNodeRestarted` (severity `info`) is new — it's a low-urgency signal (a
single restart is often a benign redeploy) so it's fine to leave unrouted in
Alertmanager or send to a low-noise channel; only repeated restarts in a
short window are actionable.

## Metric names

The `prismo-node` alert group (in `alert-rules.yaml`) uses only real
cdk-erigon metric names, confirmed against a live v2.61.24 node's
`http://<host>:9091/debug/metrics/prometheus` output — `sync{stage=...}`,
`last_checked_l1_block`, `rpc_failure`, `up`, `process_start_time_seconds`.
None of these are prefixed `prismo_`; that prefix never existed on this
binary and was a placeholder in the pre-2026-07-08 version of this file.

`prismo_`-prefixed names DO still appear in the `prismo-watchtower` and
`prismo-bridge` groups — those remain genuine placeholders (see the header
comment above each group in `alert-rules.yaml`) because the watchtower
binary doesn't exist yet beyond a placeholder image and the bridge-indexer's
real `/metrics` output hasn't been captured against a live instance the way
cdk-erigon's was. Re-run the same capture-and-verify pass on those roles
before relying on their alerts, or before assuming their metric names are
correct.
