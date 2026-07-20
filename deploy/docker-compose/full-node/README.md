# Full Node — Docker Compose

Independent state-verifying node. Runs L1 (geth + lighthouse) + cdk-erigon configured to derive state from L1 only. Works on either network — `NETWORK=testnet` runs Sepolia alongside, `NETWORK=mainnet` runs Ethereum.

> **KNOWN BLOCKER (2026-07-08): this role does not currently boot on cdk-erigon v2.61.24.**
> `--zkevm.l1-sync-start-block` (the flag that puts cdk-erigon into L1-only
> "don't trust the datastream" mode) is gated in this binary by
> `sequencer.IsSequencer()` (`CDK_ERIGON_SEQUENCER=1`) — see
> `eth/backend.go:1044-1049` in the `0xPolygon/cdk-erigon` v2.61.24 tag. Any
> process with that flag set that is NOT running as the actual trusted
> sequencer panics on boot with `you cannot launch in l1 sync mode as an RPC
> node`. Confirmed live via an isolated container run against this image
> (not by running this compose stack, which would also need hours of L1
> checkpoint sync first). Setting `CDK_ERIGON_SEQUENCER=1` here is NOT a
> workaround — it makes this process behave as the real sequencer (batch
> production, executor requirements), which is unsafe for an
> operator-run verifying node. The compose file's flags are otherwise
> corrected (real flag names, required flags present, volume permissions
> fixed) so it fails only at this one gate — this needs a design decision
> (upstream feature request, a different cdk-erigon build, or dropping this
> role) before it can be offered as working. Do not remove this notice
> without re-verifying against a fixed binary.

## Steps

```bash
cd deploy/docker-compose/full-node
cp .env.example .env
# Edit .env — set NETWORK (testnet|mainnet)

# Generate JWT secret for geth↔lighthouse handshake
NETWORK_LOWER=$(awk -F= '/^NETWORK=/{print $2}' .env)
docker volume create prismo-full-${NETWORK_LOWER}_l1-geth
docker run --rm -v prismo-full-${NETWORK_LOWER}_l1-geth:/data alpine:3.20 sh -c \
  "head -c 32 /dev/urandom | xxd -p -c 32 > /data/jwt.hex && chmod 600 /data/jwt.hex"

../../../scripts/compose.sh full-node up -d
../../../scripts/compose.sh full-node logs -f cdk-erigon
```

First boot: L1 syncs (~1–2 hours via checkpoint sync on testnet, longer on mainnet), then cdk-erigon catches up. Use a snapshot for faster start.

## Disk

| Volume | Testnet (Sepolia) | Mainnet (Ethereum) |
|---|---|---|
| `l1-geth` | ~120 GB | ~1.2 TB |
| `l1-lh` | ~80 GB | ~150 GB |
| `chaindata` (Prismo) | ~50 GB + 30 GB/month | TBD |

## Difference from RPC node

This node refuses to advance from sequencer-stream-only data. If you only care about serving `eth_*` calls fast, run the RPC node. If you care about catching protocol misbehavior, run this — and you'll want to run it on mainnet day one.
