# RPC Node — Kubernetes

Self-serve `cdk-erigon` RPC node using the chart vendored in this repo at
[`deploy/kubernetes/chart`](../chart). No external chart dependency — clone
this repo and `helm install`.

## Quickstart

From the repo root — pick the values file for your network:

| Network | Values file | L1 endpoint you supply |
|---|---|---|
| Mainnet (Prismo Glass, 328) | `deploy/kubernetes/rpc-node/values-mainnet.yaml` | Ethereum mainnet |
| Testnet (Glassnet, 101001000) | `deploy/kubernetes/rpc-node/values.yaml` | Sepolia |

```bash
# mainnet
helm install prismo-rpc ./deploy/kubernetes/chart \
  -f deploy/kubernetes/rpc-node/values-mainnet.yaml \
  -n prismo --create-namespace \
  --set config.l1RpcUrl="$L1_RPC_URL_MAINNET"

# testnet
helm install prismo-rpc ./deploy/kubernetes/chart \
  -f deploy/kubernetes/rpc-node/values.yaml \
  -n prismo --create-namespace \
  --set config.l1RpcUrl="$L1_RPC_URL_SEPOLIA"
```

Read [docs/02-network-config.md — Mainnet facts operators must know](../../../docs/02-network-config.md#mainnet-facts-operators-must-know) before exposing a mainnet node.

`$L1_RPC_URL_MAINNET` / `$L1_RPC_URL_SEPOLIA` is a read-only L1 JSON-RPC endpoint (Alchemy,
Infura, Ankr, dRPC, or your own node) — cdk-erigon uses it at roughly
1 req/s steady-state. There is no public default; the chart's `required`
guards will not stop you from installing with it blank, but the pod will
crashloop until you set it (cdk-erigon panics without a usable
`--zkevm.l1-rpc-url`).

Prefer a Secret over `--set` in anything beyond local testing — `--set`
values are visible in `helm get values` / release history:

```bash
kubectl create secret generic prismo-rpc-l1 -n prismo \
  --from-literal=url="$L1_RPC_URL_SEPOLIA"

helm install prismo-rpc ./deploy/kubernetes/chart \
  -f deploy/kubernetes/rpc-node/values.yaml \
  -n prismo --create-namespace \
  --set config.l1RpcUrlSecret.name=prismo-rpc-l1 \
  --set config.l1RpcUrlSecret.key=url
```

## Verify it's syncing

```bash
kubectl get pods -n prismo -l app.kubernetes.io/instance=prismo-rpc
kubectl logs -n prismo -l app.kubernetes.io/instance=prismo-rpc -f

# Port-forward and check the head is advancing
kubectl port-forward -n prismo svc/prismo-rpc-prismo-rpc-node 8545:8545
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://127.0.0.1:8545
```

The Service/StatefulSet/ConfigMap name is `<release>-<chart-name>` unless the
release name already contains the chart name — with `helm install prismo-rpc`
and chart name `prismo-rpc-node` that's `prismo-rpc-prismo-rpc-node` (Helm's
standard `fullname` collision-avoidance logic; see
`chart/templates/_helpers.tpl`). Run `kubectl get all -n prismo` if unsure, or
set `--set fullnameOverride=prismo-rpc` at install time for a shorter name.

## What's in the values files

`values.yaml` (testnet, `dynamic-glassnet`) and `values-mainnet.yaml`
(mainnet, `dynamic-glass`) carry real values for this chart — chain ID, L1
first block, contract addresses, sequencer RPC, and datastream host:port,
pre-filled from [`configs/networks/<network>.env`](../../../configs/networks/).
The only thing you must supply is `config.l1RpcUrl` (or
`config.l1RpcUrlSecret`) — see Quickstart above. One values file == one
network; the chart has no `networks.<name>` switch.

## Chain files

The chart bundles both chains' `dynamic-<chain>-{allocs,conf,chainspec}.json`
at `deploy/kubernetes/chart/files/` and renders the set selected by
`config.chainName` into the same ConfigMap as `config.yaml` (cdk-erigon
requires these to sit next to its `--config` file).
They're byte-identical mirrors of `configs/dynamic-*.json` — see
[`deploy/kubernetes/chart/files/README.md`](../chart/files/README.md) and
[`deploy/kubernetes/sync-chart-files.sh`](../sync-chart-files.sh) for how
they're kept in sync, and [`configs/CHECKSUMS.txt`](../../../configs/CHECKSUMS.txt)
to verify independently.

## Restoring from a snapshot

Skip historical sync — see [`docs/03-snapshots.md`](../../../docs/03-snapshots.md#restore--kubernetes).
Short version:

```bash
helm install prismo-rpc ./deploy/kubernetes/chart \
  -f deploy/kubernetes/rpc-node/values.yaml \
  -n prismo --create-namespace \
  --set config.l1RpcUrl="$L1_RPC_URL_SEPOLIA" \
  --set snapshot.enabled=true \
  --set snapshot.url="https://snapshots.glassnet.prismo.network/cdk-erigon/dynamic-glassnet/<height>/datadir.tar.zst" \
  --set snapshot.sha256="<sha256 from index.json>"
```

The `restore-snapshot` init container needs to run as root to install
`zstd`/`curl` and `chown` the restored tree — it is a deliberate, narrow
exception to this chart's otherwise PodSecurity-`restricted`-compliant
posture (see the comment in `chart/templates/statefulset.yaml`). A namespace
that *enforces* the `restricted` Pod Security Standard will reject the pod
while `snapshot.enabled=true`; either relax enforcement for the one-time
restore, or use the "Manual PVC populate" option in `docs/03-snapshots.md`
instead.

## Exposing it publicly

`ingress.enabled` is `false` by default — bring your own `Ingress` (NGINX,
ALB, etc.) with TLS termination and a rate limit / method allowlist in front.
See [`docs/04-security.md`](../../../docs/04-security.md). The chart exposes
WebSocket directly from cdk-erigon (`--ws.addr=0.0.0.0`, `ws.port`) rather
than through an nginx sidecar — proven to work over a raw WebSocket
handshake in the docker-compose deploy (see repo audit history); add your own
sidecar only if you need to strip a browser `Origin` header for dApp clients.

## Monitoring

Set `monitoring.serviceMonitor.enabled=true` if a Prometheus Operator
(e.g. kube-prometheus-stack) is installed in-cluster. Metrics are served at
`/debug/metrics/prometheus` on port `9091` — NOT `/metrics` (this is an
Erigon-family quirk, not a Prometheus Operator default).

## NetworkPolicy

This chart does not ship a NetworkPolicy. If your namespace defaults to
deny-all, allow:

- Ingress from your ingress controller's namespace on `8545`/`8546`.
- Ingress from Prometheus on `9091`.
- Egress to your L1 RPC endpoint, the network's datastream host on `6900`
  and sequencer RPC on `443` (mainnet: `datastream.prismo.network`,
  `sequencer.prismo.network`; testnet: `datastream.glassnet.prismo.network`,
  `sequencer.glassnet.prismo.network`), and DNS.
