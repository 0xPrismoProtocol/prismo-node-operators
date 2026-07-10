# Contributing

## Scope of this repo

Operator-facing infrastructure: deploy manifests, configs, monitoring, runbooks. Protocol changes go to the upstream Prismo core repo (TBD).

## What we accept

- Fixes to deploy manifests (Docker Compose, systemd, k8s, Terraform)
- Corrections to chain config / contract addresses (must cite source) — testnet *or* mainnet
- Mainnet population PRs — replacing `TBD` in `configs/networks/mainnet.{env,json}` once contracts are deployed (must cite the deploy tx / commit)
- New operator runbooks and troubleshooting entries
- Monitoring rules: Prometheus alerts, Grafana panels
- New deploy targets (e.g. NixOS module, Ansible role) — open an issue first
- New networks (e.g. staging) — add `configs/networks/<name>.{env,json}` and update tables

## Network parity rule

A change that touches a per-network value must update **both** `testnet.env` and `mainnet.env` (mainnet stays `TBD` if the value isn't known yet — but the *key* must exist on both sides). Same for the JSON twins. Keeps the env-var contract stable.

## What we don't accept here

- Sequencer / aggregator code changes — upstream
- Protocol upgrades — upstream
- Marketing / branding PRs

## Local checks before PR

```bash
# YAML lint
yamllint deploy/ configs/

# Shell lint
shellcheck scripts/*.sh deploy/**/install.sh

# Terraform
terraform -chdir=deploy/cloud/aws/rpc-node fmt -check
terraform -chdir=deploy/cloud/aws/rpc-node validate

# Docker Compose — render with each network to catch missing vars
( cd deploy/docker-compose/rpc-node && \
  NETWORK=testnet docker compose --env-file ../../../configs/networks/testnet.env config -q && \
  NETWORK=mainnet docker compose --env-file ../../../configs/networks/mainnet.env config -q )
```

## Commit style

Conventional commits:

```
docs(rpc-node): clarify snapshot verification step
fix(systemd): correct ExecStart path on Ubuntu 24.04
feat(monitoring): add l1-finality-lag alert
```

## Reporting security issues

**Do not open public issues for security vulnerabilities.** Email security@prismo.example (placeholder — update once channel exists).
