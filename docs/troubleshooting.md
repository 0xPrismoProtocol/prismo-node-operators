# Troubleshooting

Common failure modes and their fixes.

## Node won't sync past a certain block

**Symptom**: `head block` stuck at N, logs show `failed to fetch batch` or `unable to reach datastreamer`.

Possible causes:

| Cause | Check | Fix |
|---|---|---|
| Sequencer data stream unreachable | `nc -zv $DATASTREAM_HOST $DATASTREAM_PORT` | Verify outbound port open; `DATASTREAM_HOST` in `configs/networks/<NETWORK>.env` correct |
| L1 RPC throttled | grep `429` or `rate limit` in logs | Switch to a less throttled provider, or self-host the L1 (Sepolia for testnet, Ethereum for mainnet) |
| Wrong L1 first block | check `--zkevm.l1-first-block` matches `L1_FIRST_BLOCK` from the active network env | Correct env value and resync from a snapshot |
| Datastream version mismatch | check `--zkevm.datastream-version` matches `DATASTREAM_VERSION` (2) | Update config |
| Wrong NETWORK selected | `printenv NETWORK`; compare `eth_chainId` against `L2_CHAIN_ID` from the active env | Re-source the right `configs/networks/*.env` and restart |

## "BadBlock" or state-root mismatch

**Symptom**: `BadBlock`, `state root mismatch`, or `executor verification failed` in logs.

This is the alarm scenario watchtowers exist for. Steps:

1. Stop the node.
2. Capture the failing block number and the diverging state root from logs.
3. Compare with a second independent full node: `eth_getBlockByNumber` for the same height.
4. If they agree and the official node disagrees → potential incident. Open an issue and notify watchtower channel.
5. If your node is the outlier → likely corrupted data dir. Re-sync from a fresh snapshot, or from genesis.

## RPC returns `method not found`

The default API allowlist (`eth, net, web3, txpool, zkevm`) excludes `debug_*`, `trace_*`, `admin_*`. Either:

- Add them to `http.api` (private endpoints only — see [04-security.md](04-security.md)).
- Or route those requests to an archive node.

## Out of disk space

```bash
# How big is the data dir?
du -sh /var/lib/prismo

# Pruning settings — the shipped default is unpruned (no prune.* flags), so
# this will normally print nothing. If you opted into pruning, check it's set:
grep -E "^prune" /etc/prismo/chain-config.yaml
```

See [Pruning vs archive](nodes/rpc-node.md#pruning-vs-archive) for why unpruned is the default and how to opt in.

If archive mode wasn't intended, switch to pruned and resync. Don't try to selectively delete files in the data dir.

## Bridge indexer Merkle proof mismatch

**Symptom**: User reports `claim` reverts on L1 with "invalid smt proof".

Causes:

1. Indexer is behind — let it catch up to current L2 head.
2. Indexer DB corrupted — drop and re-index from L1 first block (`L1_FIRST_BLOCK` in the active network env).
3. Wrong bridge contract address in config — verify `BRIDGE_L1` / `BRIDGE_L2` from `configs/networks/<NETWORK>.env`. See [02-network-config.md](02-network-config.md).
4. NETWORK mismatch — indexer pointed at testnet contracts while RPC is mainnet (or vice versa).

## Watchtower false positives

Watchtower compares the L1-posted state root vs your local full node's computed root. False positives usually mean:

- Your full node is not yet at the verified batch height.
- Your full node uses a different L1 RPC and saw different data (rare, indicates DA issue).

Increase `verifyDelayBlocks` in watchtower config to wait for L1 finality before alerting.

## Logs to grab when filing an issue

```bash
# Last 1000 lines of cdk-erigon (container name is prismo-cdk-erigon-<network>,
# e.g. prismo-cdk-erigon-testnet)
docker logs --tail=1000 prismo-cdk-erigon-testnet > cdk-erigon.log

# Or, for systemd:
journalctl -u cdk-erigon -n 1000 --no-pager > cdk-erigon.log

# Sync status
curl -s -X POST http://localhost:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}'

# Latest block
curl -s -X POST http://localhost:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Disk + memory
df -h /var/lib/prismo
free -h
```

Attach `cdk-erigon.log` and the JSON-RPC outputs to your issue.
