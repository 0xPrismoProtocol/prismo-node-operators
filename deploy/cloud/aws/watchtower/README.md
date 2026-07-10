# Watchtower — AWS

Tiny instance — `t3.medium` is plenty.

Pattern: copy `../rpc-node/main.tf`, change `instance_type` to `t3.medium`, drop the EBS data volume (50 GB root is enough), swap the compose path in `cloud-init.yaml` to `deploy/docker-compose/watchtower/`. Pass `network` var to deploy a testnet or mainnet watchtower.

For the safest setup, run **two** watchtowers per network — different regions, different L1 RPC providers — and treat any disagreement between them as itself a signal.

Or skip Terraform and run the watchtower on an existing host that already has access to your full node on the matching network.
