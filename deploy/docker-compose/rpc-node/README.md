# RPC Node — Docker Compose

Single-host RPC node. ~10 minutes from clone to syncing. Works for both `NETWORK=testnet` and `NETWORK=mainnet`; per-network values come from [`configs/networks/<NETWORK>.env`](../../../configs/networks/).

## Steps

```bash
cd deploy/docker-compose/rpc-node
cp .env.example .env
# Edit .env — pick NETWORK, set L1_RPC_URL

# Use the wrapper so the network env + your .env are merged for substitution:
../../../scripts/compose.sh rpc-node up -d
../../../scripts/compose.sh rpc-node logs -f cdk-erigon
```

Or run plain `docker compose` if you've sourced both env files into your shell:

```bash
set -a
. ../../../configs/networks/$(awk -F= '/^NETWORK=/{print $2}' .env).env
. .env
set +a
docker compose up -d
```

## Optional — restore from snapshot

Skip historical sync (~hours saved):

```bash
set -a; . ../../../configs/networks/${NETWORK:-testnet}.env; set +a
SNAP_URL="${SNAPSHOTS_BASE}/cdk-erigon/${L2_CHAIN_NAME}/<height>/datadir.tar.zst"
SNAP_SHA="..."

../../../scripts/compose.sh rpc-node down

# busybox tar (alpine) does not support --use-compress-program — pipe
# through unzstd instead. The chown matters: the compose runs cdk-erigon as
# 10000:10000. Volume name is "<project>_chaindata" — for this role/network
# that's prismo-rpc-${NETWORK:-testnet}_chaindata (prismo-rpc-testnet_chaindata
# on testnet). See docs/03-snapshots.md for the canonical version of this.
docker run --rm -v prismo-rpc-${NETWORK:-testnet}_chaindata:/data --user 0:0 alpine sh -c "apk add -q zstd curl && \
  curl -sL $SNAP_URL -o /tmp/snap.tar.zst && \
  echo \"$SNAP_SHA  /tmp/snap.tar.zst\" | sha256sum -c - && \
  unzstd -c /tmp/snap.tar.zst | tar -xf - -C /data && \
  rm /tmp/snap.tar.zst && chown -R 10000:10000 /data"

../../../scripts/compose.sh rpc-node up -d
```

## Health

```bash
../../../scripts/healthcheck.sh http://localhost:8545
```

## Reverse proxy

Bind in this compose file is `127.0.0.1:8545`. Put nginx (or Caddy) on `:443` to expose with TLS + rate-limit. See [docs/04-security.md](../../../docs/04-security.md).

## Updating

```bash
../../../scripts/compose.sh rpc-node pull   # only after reading the cdk-erigon changelog
../../../scripts/compose.sh rpc-node up -d
```

Pin versions in `docker-compose.yml` — never use `:latest` in production.

## Resources

| Resource | Value |
|---|---|
| CPU | up to ~4 cores under load, idle <1 |
| RAM | 16–30 GB |
| Disk | starts at ~50 GB (snapshot), grows ~30 GB/month on testnet |

Mainnet sizing TBD — expect higher RAM and disk under sustained load.
