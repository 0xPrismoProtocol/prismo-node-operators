# Full Node — Azure (Terraform)

Self-contained module: RG + VNet + NSG + public IP + `Standard_D16s_v5` (16 vCPU / 64 GB) VM + 2 TB Premium_LRS data disk. Runs the docker-compose **full-node** stack (Prismo + L1 geth + L1 lighthouse) via cloud-init. `network` var picks testnet/mainnet — the compose selects `--sepolia`/`--mainnet` from `L1_NETWORK_FLAG` in the active network env.

NSG opens SSH + L1 P2P (`30303`, `9000`) inbound for healthy peering. No public RPC port — a full node is for validating, not serving; expose RPC only behind your own gateway.

## Steps

```bash
az login
cd deploy/cloud/azure/full-node
terraform init

# Testnet
terraform apply \
  -var "network=testnet" \
  -var "ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)" \
  -var "l1_rpc_url=https://sepolia.example/your-key" \
  -var 'allowed_ssh_cidrs=["YOUR.IP.HERE/32"]'

# Mainnet (after configs/networks/mainnet.env is populated) — bump data_disk_gb to 4096+
terraform apply \
  -var "network=mainnet" \
  -var "data_disk_gb=4096" \
  -var "ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)" \
  -var "l1_rpc_url=https://mainnet.example/your-key"
```

## Cost (East US, pay-as-you-go)

| Item | Monthly |
|---|---:|
| `Standard_D16s_v5` | ~$680 |
| 2 TB Premium SSD (P40) + 50 GB OS | ~$290 |
| **Total** | **~$970** |

Reserved instance cuts compute ~40%. Mainnet (4 TB + larger VM) runs materially higher — budget accordingly.

## Tear down

```bash
terraform destroy
```
