# Bridge Indexer — AWS

Recommended:

- `t3.large` (2 vCPU, 8 GB) for the bridge service on testnet. Mainnet TBD — start at `t3.xlarge` and right-size.
- **External RDS Postgres** instead of the bundled container — bridge state is your indexer's source of truth. Use `db.t4g.medium` (testnet) / `db.r6g.large` (mainnet), multi-AZ for production.

Adapt `../rpc-node/main.tf`:

- Pass through `network` var.
- Change `instance_type` to `t3.large` (testnet) / `t3.xlarge` (mainnet).
- Replace the EBS data volume with a `db_subnet_group` + `aws_db_instance` (Postgres 16).
- Swap the compose path to `deploy/docker-compose/bridge-indexer/`, and override the DB host in `config.toml` to point at the RDS endpoint.

Reference DB instance:

```hcl
resource "aws_db_instance" "bridge" {
  identifier              = "prismo-bridge-${var.network}"
  engine                  = "postgres"
  engine_version          = "16.3"
  instance_class          = var.network == "mainnet" ? "db.r6g.large" : "db.t4g.medium"
  allocated_storage       = var.network == "mainnet" ? 500 : 200
  storage_type            = "gp3"
  username                = "bridge"
  password                = var.db_password
  db_name                 = "bridge"
  multi_az                = true
  backup_retention_period = var.network == "mainnet" ? 30 : 7
  skip_final_snapshot     = false
  publicly_accessible     = false
}
```
