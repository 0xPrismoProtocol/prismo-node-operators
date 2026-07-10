# Full Node — Hetzner

For the full-node + co-located L1 stack, prefer Hetzner's **AX42** dedicated server (Ryzen 7, 64 GB DDR4, 2× 1 TB NVMe) — far better IOPS than cloud volumes for ~€44/mo. Spin via Robot console (no Terraform provider for AX line) and provision with the same `cloud-init.yaml` from `../rpc-node/` adapted to launch `deploy/docker-compose/full-node/`. Pass `network=testnet` or `network=mainnet`; the full-node compose picks the right L1 client flag.

Cloud-only path: copy `../rpc-node/main.tf`, bump `server_type` to `ccx33` (8 vCPU, 32 GB) and `data_volume_gb` to 2048 for testnet, 4096+ for mainnet.
