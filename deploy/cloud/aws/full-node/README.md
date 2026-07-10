# Full Node — AWS

Same Terraform pattern as `../rpc-node/`, but:

- Bump `instance_type` to `m6i.4xlarge` (16 vCPU / 64 GB) — full node + L1 execution + consensus on one box.
- Bump `data_disk_gb` to `2048` for testnet, `4096+` for mainnet (Prismo data + L1 geth + L1 lighthouse).
- Replace the `cloud-init.yaml` `runcmd` to launch `deploy/docker-compose/full-node/docker-compose.yml` instead of `rpc-node`.
- Pass through `network` var (already supported in `../rpc-node/main.tf`) — the full-node compose picks `--sepolia` or `--mainnet` from `L1_NETWORK_FLAG` in the active network env.

Until a fully separate Terraform module is published, copy `../rpc-node/main.tf`, change defaults, swap the compose path. Contributions welcome.
