# Watchtower — Kubernetes

Lightweight Deployment. No persistence required (state is small and re-derivable). Runs alongside a full node in the same namespace, on the same network.

```bash
# Pick the L2 RPC for the network you're watching
L2_RPC_URL="http://prismo-full.operator-testnet.svc.cluster.local:8545"

kubectl create secret generic prismo-watchtower-env -n operator-testnet \
  --from-literal=L1_RPC_URL="$L1_RPC_URL" \
  --from-literal=L2_RPC_URL="$L2_RPC_URL" \
  --from-literal=SLACK_WEBHOOK_URL="$SLACK_WEBHOOK_URL"

helm upgrade --install prismo-watchtower ./prismo-watchtower-chart \
  -n operator-testnet -f values.yaml --set network=testnet
```

Repeat with `-n operator-mainnet --set network=mainnet` for a mainnet watchtower (pointing at a mainnet full node).

Chart TODO — until published, deploy with a hand-rolled Deployment manifest using the same fields.
