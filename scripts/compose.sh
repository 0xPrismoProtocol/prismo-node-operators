#!/usr/bin/env bash
# Wrapper: run docker compose in a role's dir with both the network env and the
# role's .env loaded as substitution variables.
#
# Usage:
#   scripts/compose.sh <role> [docker compose args...]
#
# Examples:
#   scripts/compose.sh rpc-node up -d
#   scripts/compose.sh full-node logs -f cdk-erigon
#   NETWORK=mainnet scripts/compose.sh rpc-node config -q
#
# Resolution order (later wins):
#   1. configs/networks/<NETWORK>.env  (canonical per-network values)
#   2. deploy/docker-compose/<role>/.env  (operator overrides + secrets)
set -euo pipefail

ROLE="${1:?role required (rpc-node|full-node|watchtower|bridge-indexer)}"
shift || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROLE_DIR="$SCRIPT_DIR/../deploy/docker-compose/$ROLE"
[[ -d "$ROLE_DIR" ]] || { echo "no such role dir: $ROLE_DIR" >&2; exit 1; }

if [[ ! -f "$ROLE_DIR/.env" ]]; then
  echo "missing $ROLE_DIR/.env — copy from $ROLE_DIR/.env.example and edit" >&2
  exit 1
fi

# Read NETWORK from the role's .env if not in the shell.
if [[ -z "${NETWORK:-}" ]]; then
  NETWORK="$(awk -F= '/^NETWORK=/ {print $2; exit}' "$ROLE_DIR/.env")"
fi
NETWORK="${NETWORK:-testnet}"

NET_FILE="$SCRIPT_DIR/../configs/networks/${NETWORK}.env"
[[ -f "$NET_FILE" ]] || { echo "unknown NETWORK=$NETWORK (no $NET_FILE)" >&2; exit 1; }

# The role's .env may carry its own NETWORK= line. Sourcing it below would
# silently overwrite the shell's choice AFTER the other network's values were
# loaded — project/container names (prismo-<role>-${NETWORK}) would say one
# network while every chain flag says the other. Refuse rather than mix.
_ENV_NETWORK="$(awk -F= '/^NETWORK=/ {print $2; exit}' "$ROLE_DIR/.env")"
if [[ -n "$_ENV_NETWORK" && "$_ENV_NETWORK" != "$NETWORK" ]]; then
  echo "NETWORK=$NETWORK in the shell but $ROLE_DIR/.env says NETWORK=$_ENV_NETWORK — fix one of them" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$NET_FILE"
# shellcheck disable=SC1091
. "$ROLE_DIR/.env"
set +a

export NETWORK

exec docker compose \
  -f "$ROLE_DIR/docker-compose.yml" \
  --project-directory "$ROLE_DIR" \
  "$@"
