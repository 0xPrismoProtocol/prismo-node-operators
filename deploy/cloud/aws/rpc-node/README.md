# RPC Node — AWS (Terraform)

Spins up a single `m6i.2xlarge` with a 1 TB gp3 data disk, runs the docker-compose RPC node via cloud-init. Same module deploys testnet or mainnet — `network` var picks which.

## Steps

```bash
cd deploy/cloud/aws/rpc-node
terraform init

# Testnet
terraform apply \
  -var "network=testnet" \
  -var "key_name=my-keypair" \
  -var "l1_rpc_url=https://sepolia.example/your-key" \
  -var 'allowed_ssh_cidrs=["YOUR.IP.HERE/32"]'

# Mainnet (after configs/networks/mainnet.env is populated)
terraform apply \
  -var "network=mainnet" \
  -var "key_name=my-keypair" \
  -var "l1_rpc_url=https://mainnet.example/your-key" \
  -var 'allowed_ssh_cidrs=["YOUR.IP.HERE/32"]'
```

To run both: use a separate Terraform workspace per network (`terraform workspace new mainnet`).

Output prints the public IP. Then:

1. Point a DNS A record (e.g. `rpc.testnet.your-domain.example` or `rpc.your-domain.example`) at it.
2. SSH in: `ssh ubuntu@<ip>`.
3. `sudo certbot --nginx -d <hostname>` for TLS.
4. Configure nginx upstream (see [`docs/04-security.md`](../../../../docs/04-security.md)).

## Cost (us-east-1, on-demand)

| Item | Monthly |
|---|---:|
| `m6i.2xlarge` | ~$280 |
| 1 TB gp3 + 50 GB root | ~$85 |
| Data transfer (assume 100 GB/mo egress) | ~$9 |
| **Total** | **~$374** |

Reserved instances or Savings Plans cut compute by ~30%. Mainnet sizing TBD — likely larger instance + more disk.

> This module deploys the **headroom tier** — roughly 2× the documented minimum in [docs/01-hardware.md](../../../../docs/01-hardware.md) (4 vCPU / 8 GB / 100 GB, ~$110/mo). The extra CPU/RAM/disk is intentional production headroom, not a hard requirement.

## Tear down

```bash
terraform destroy
```
