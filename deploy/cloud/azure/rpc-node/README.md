# RPC Node — Azure (Terraform)

Spins up a single `Standard_D8s_v5` (8 vCPU / 32 GB — peer to the AWS `m6i.2xlarge`) with a 1 TB Premium_LRS data disk, runs the docker-compose RPC node via cloud-init. Same module deploys testnet or mainnet — `network` var picks which.

Creates its own resource group, VNet, subnet, NSG, and public IP, so it is self-contained and tears down cleanly.

## Prerequisites

```bash
az login
# Terraform uses the Azure CLI's active subscription. Pin one explicitly if you have several:
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

## Steps

```bash
cd deploy/cloud/azure/rpc-node
terraform init

# Testnet
terraform apply \
  -var "network=testnet" \
  -var "ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)" \
  -var "l1_rpc_url=https://sepolia.example/your-key" \
  -var 'allowed_ssh_cidrs=["YOUR.IP.HERE/32"]'

# Mainnet (after configs/networks/mainnet.env is populated)
terraform apply \
  -var "network=mainnet" \
  -var "ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)" \
  -var "l1_rpc_url=https://mainnet.example/your-key"
```

To run both: use a separate Terraform workspace per network (`terraform workspace new mainnet`). The resource-group name already carries `${network}`, so the two never collide.

Output prints the public IP. Then:

1. Point a DNS A record (e.g. `rpc.testnet.your-domain.example` or `rpc.your-domain.example`) at it.
2. SSH in: `ssh azureuser@<ip>`.
3. `sudo certbot --nginx -d <hostname>` for TLS.
4. Configure nginx upstream (see [`docs/04-security.md`](../../../../docs/04-security.md)).

## Cost (East US, pay-as-you-go)

| Item | Monthly |
|---|---:|
| `Standard_D8s_v5` | ~$340 |
| 1 TB Premium SSD (P30) + 50 GB OS | ~$150 |
| Public IP + egress (assume 100 GB/mo) | ~$12 |
| **Total** | **~$502** |

Pricier than AWS/Hetzner for the same shape — Premium SSD and egress are the drivers. A 1-year reserved instance cuts compute ~40%; swap `Premium_LRS` → `StandardSSD_LRS` on the data disk for testnet to drop disk cost ~half (benchmark IOPS first). Mainnet sizing TBD — likely `Standard_D16s_v5` + larger disk.

## Tear down

```bash
terraform destroy
```
