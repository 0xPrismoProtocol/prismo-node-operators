# RPC Node — Hetzner (Terraform)

Cheap reference deployment. CCX23 dedicated AMD server in Falkenstein, 1 TB volume. Same module deploys testnet or mainnet via the `network` var.

## Steps

```bash
export TF_VAR_hcloud_token=$(pass hetzner/api)
cd deploy/cloud/hetzner/rpc-node
terraform init

# Testnet
terraform apply \
  -var "network=testnet" \
  -var "ssh_key_name=my-hetzner-key" \
  -var "l1_rpc_url=https://sepolia.example/your-key"

# Mainnet
terraform apply \
  -var "network=mainnet" \
  -var "ssh_key_name=my-hetzner-key" \
  -var "l1_rpc_url=https://mainnet.example/your-key"
```

Then DNS + certbot like the AWS variant.

## Cost (Falkenstein)

| Item | Monthly |
|---|---:|
| CCX23 (4 vCPU AMD, 16 GB) | ~€20 |
| 1 TB volume | ~€42 |
| **Total** | **~€62** |

Hetzner egress is included up to 20 TB. Big win for high-traffic public RPC.

## Caveat

Hetzner's volumes are slower than AWS gp3 IOPS-tuned. For production sequencer/full-node workloads, prefer their dedicated NVMe AX servers. RPC is fine on the volume on testnet; for mainnet, benchmark before committing.
