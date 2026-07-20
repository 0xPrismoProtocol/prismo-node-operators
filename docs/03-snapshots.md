# Snapshots

> **Status: live.** Weekly snapshots (Sun ~07:00 UTC) — machine-readable pointers at `${SNAPSHOTS_BASE}/latest.json` (newest: `{height, timestamp, url, sha256}`) and `${SNAPSHOTS_BASE}/index.json` (recent snapshots). Restore-gate-verified 2026-07-07: download + sha256 + restore + catch-up to head, end to end.
>
> Two operational notes: (1) the published `height` is approximate (chain head at pack time; the underlying EBS snapshot is up to a day older, and its stages are crash-consistent — a restored node boots somewhat below the stamped height and replays forward); (2) snapshots come from an UNPRUNED datadir — cdk-erigon refuses `--prune` changes on an existing DB, so pruning cannot be enabled on a restored snapshot (see `configs/chain-config.yaml`).

Skip historical sync (~hours → minutes) by restoring from a published chain-data snapshot.

Snapshots are per-network. Use the matching base URL from [`configs/networks/<NETWORK>.env`](../configs/networks/) (`SNAPSHOTS_BASE`).

## Where snapshots live

```
${SNAPSHOTS_BASE}/cdk-erigon/<L2_CHAIN_NAME>/<height>/<file>.tar.zst
```

Example (testnet):

```
https://snapshots.glassnet.prismo.network/cdk-erigon/dynamic-glassnet/<height>/datadir.tar.zst
```

Snapshot index per network:

```
${SNAPSHOTS_INDEX}      # e.g. https://snapshots.glassnet.prismo.network/index.json
```

`index.json` shape:

```json
[
  {
    "network": "testnet",
    "l2_chain_name": "dynamic-glassnet",
    "height": 1234567,
    "timestamp": "2026-05-01T00:00:00Z",
    "size_bytes": 187423991234,
    "url": "https://.../cdk-erigon/dynamic-glassnet/1234567/datadir.tar.zst",
    "sha256": "abc123…",
    "node_type": "rpc"
  }
]
```

## Restore — Docker Compose

```bash
# Load network values into the shell so SNAPSHOTS_BASE / L2_CHAIN_NAME resolve.
set -a; source ../../../configs/networks/${NETWORK:-testnet}.env; set +a

cd deploy/docker-compose/rpc-node

# Use the wrapper, not `docker compose` directly — see docs/nodes/rpc-node.md.
../../../scripts/compose.sh rpc-node down

# Pick a snapshot URL from the index
SNAP_URL="${SNAPSHOTS_BASE}/cdk-erigon/${L2_CHAIN_NAME}/1234567/datadir.tar.zst"
SNAP_SHA="abc123…"

# Verify and extract into the named volume. NOTE: busybox tar (alpine) does
# not support --use-compress-program — pipe through unzstd instead. The chown
# matters: the compose runs cdk-erigon as 10000:10000.
docker run --rm -v prismo-rpc-testnet_chaindata:/data --user 0:0 alpine:3.20 sh -c "apk add -q zstd curl && \
  curl -sL $SNAP_URL -o /tmp/snap.tar.zst && \
  echo \"$SNAP_SHA  /tmp/snap.tar.zst\" | sha256sum -c - && \
  unzstd -c /tmp/snap.tar.zst | tar -xf - -C /data && \
  rm /tmp/snap.tar.zst && chown -R 10000:10000 /data"

../../../scripts/compose.sh rpc-node up -d
```

Convenience script: [`scripts/verify-snapshot.sh`](../scripts/verify-snapshot.sh).

## Restore — systemd / bare-metal

```bash
sudo systemctl stop cdk-erigon

# Pick a snapshot URL from the index
SNAP_URL="${SNAPSHOTS_BASE}/cdk-erigon/${L2_CHAIN_NAME}/1234567/datadir.tar.zst"
SNAP_SHA="abc123…"

# Download + verify to a temp file, then extract into the datadir (NOT
# /var/lib/prismo — the unit's --datadir is /var/lib/prismo/data, and
# extracting one level up silently no-ops: cdk-erigon just starts a fresh
# sync as if nothing were restored).
curl -sL "$SNAP_URL" -o /tmp/snap.tar.zst
echo "$SNAP_SHA  /tmp/snap.tar.zst" | sha256sum -c -
sudo -u prismo bash -c "unzstd -c /tmp/snap.tar.zst | tar -xf - -C /var/lib/prismo/data"
rm /tmp/snap.tar.zst
sudo chown -R prismo:prismo /var/lib/prismo/data

sudo systemctl start cdk-erigon
```

## Restore — Kubernetes

Two options:

1. **Init container**: see `deploy/kubernetes/rpc-node/values.yaml` — set `snapshot.enabled=true` and `snapshot.url=…`. The chart adds a `restore-snapshot` init container.
2. **Manual PVC populate**: spin up a one-shot pod with the PVC mounted, curl + extract, delete pod, then start the StatefulSet.

## Snapshot trust

Snapshots are a convenience, not a security feature. To verify integrity:

1. Check the published `sha256`.
2. After restore, let the node sync to head and watch for `BadBlock` / state-root mismatch in logs.
3. Ideally: also run a watchtower for at least 24 h alongside.

If you don't trust the snapshot publisher, sync from genesis. It is slow but reproducible. **For mainnet**, prefer genesis sync or a snapshot you cross-check against a second independent publisher before trusting.

## Publishing your own snapshot

Operators are encouraged to publish snapshots. Suggested layout:

```
my-snapshots.example/
└── prismo/
    ├── index.json
    └── <l2_chain_name>/         # e.g. dynamic-glassnet for testnet
        └── <height>/
            ├── datadir.tar.zst
            └── datadir.tar.zst.sha256
```

The official Prismo snapshots (see above) are built by an internal publisher pipeline that isn't part of this repo. There's no packer script shipped here yet — write your own following the `index.json` shape and layout above (pack the datadir with `tar` + `zstd`, publish alongside a `sha256`).
