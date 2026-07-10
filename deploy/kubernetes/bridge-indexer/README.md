# Bridge Indexer — Kubernetes

Two pods: `bridge-service` (stateless, scale horizontally) and Postgres (use managed for prod, mandatory for mainnet).

```bash
# Testnet
kubectl create secret generic bridge-pg -n operator-testnet \
  --from-literal=password="$(openssl rand -base64 32)"
kubectl create secret generic bridge-env -n operator-testnet \
  --from-literal=L1_RPC_URL="$L1_RPC_URL"

helm upgrade --install prismo-bridge ./prismo-bridge-chart \
  -n operator-testnet -f values.yaml --set network=testnet
```

Repeat with `-n operator-mainnet --set network=mainnet` once `networks.mainnet.contracts.*` are populated.

Chart TODO. Reference manifests in upstream `polygonzkevm/zkevm-bridge-service`.
