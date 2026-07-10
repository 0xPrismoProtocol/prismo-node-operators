# Watchtower — Azure (Terraform)

Self-contained module: RG + VNet + NSG + public IP + tiny `Standard_B2s` (2 vCPU / 4 GB) VM, no data disk (the watchtower keeps no chain state). Runs the docker-compose **watchtower** stack via cloud-init. Outbound-only — SSH is the only inbound NSG rule.

Needs both an L1 RPC and an L2 RPC (point `l2_rpc_url` at your own full node) so it can cross-check what the sequencer publishes.

## Steps

```bash
az login
cd deploy/cloud/azure/watchtower
terraform init

terraform apply \
  -var "network=testnet" \
  -var "ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)" \
  -var "l1_rpc_url=https://sepolia.example/your-key" \
  -var "l2_rpc_url=https://rpc.testnet.your-domain.example" \
  -var 'allowed_ssh_cidrs=["YOUR.IP.HERE/32"]'
```

For the safest setup, run **two** watchtowers per network — different Azure regions, different L1 RPC providers — and treat any disagreement between them as itself a signal.

## Cost (East US, pay-as-you-go)

| Item | Monthly |
|---|---:|
| `Standard_B2s` | ~$30 |
| 50 GB StandardSSD OS disk | ~$5 |
| **Total** | **~$35** |

## Tear down

```bash
terraform destroy
```
