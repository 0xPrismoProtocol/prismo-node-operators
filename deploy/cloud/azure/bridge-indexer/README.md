# Bridge Indexer — Azure (Terraform)

Self-contained module: RG + VNet (app + delegated DB subnet) + NSG + `Standard_B2ms` (2 vCPU / 8 GB) VM **plus a managed Azure Database for PostgreSQL Flexible Server** (Postgres 16). Bridge state is the indexer's source of truth, so it lives in the managed DB, not a local disk.

The DB is private: VNet-integrated via a delegated subnet + private DNS zone, `public_network_access_enabled = false`, FQDN exported as `terraform output db_fqdn`. Note: `deploy/docker-compose/bridge-indexer` currently runs its own bundled `postgres` container (see that compose's `config.toml`, which hard-codes `Host = "postgres"`) — the Flexible Server isn't wired into the stack yet, so today it's provisioned but unused. Point the bridge service at it manually (edit `config.toml`'s `BridgeServer.DB.Host` and drop the bundled `postgres` service) if you want the managed DB in the loop.

`network` var scales both tiers:

| | testnet | mainnet |
|---|---|---|
| VM | `Standard_B2ms` | `Standard_D4s_v5` (set `-var vm_size=...`) |
| DB SKU | `B_Standard_B2ms` | `GP_Standard_D2ds_v5` |
| DB storage | 128 GB | 512 GB |
| DB HA | none | ZoneRedundant |
| Backup retention | 7 d | 30 d |

## Steps

```bash
az login
cd deploy/cloud/azure/bridge-indexer
terraform init

terraform apply \
  -var "network=testnet" \
  -var "ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)" \
  -var "l1_rpc_url=https://sepolia.example/your-key" \
  -var "l2_rpc_url=https://your-rpc-node.example" \
  -var "db_password=$(openssl rand -base64 24)" \
  -var 'allowed_ssh_cidrs=["YOUR.IP.HERE/32"]'
```

Outputs print the VM public IP and the DB FQDN. Store `db_password` in a secret manager — Terraform keeps it in state, so use a remote encrypted backend for anything beyond a throwaway testnet.

## Cost (East US, pay-as-you-go)

| Item | Monthly |
|---|---:|
| `Standard_B2ms` VM | ~$60 |
| Flexible Server `B_Standard_B2ms` + 128 GB | ~$55 |
| **Total** | **~$115** |

Mainnet (`D4s_v5` + `GP_Standard_D2ds_v5` HA) runs several times higher — HA doubles the DB cost.

## Tear down

```bash
terraform destroy
```
