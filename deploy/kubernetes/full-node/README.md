# Full Node — Kubernetes

> **This role does not currently run on cdk-erigon v2.61.24 — there is no
> working chart or values file for it here, by design.**

The independent state-verifying full node relies on cdk-erigon's L1-only sync
mode (`--zkevm.l1-sync-start-block`, "don't trust the datastream"). In the
v2.61.24 binary that flag is gated behind `CDK_ERIGON_SEQUENCER=1`
(`eth/backend.go:1044-1049`) — a non-sequencer process that sets it panics on
boot with `you cannot launch in l1 sync mode as an RPC node`, and setting the
env var turns the process INTO the trusted sequencer (unsafe for an
operator-run node). This is the same blocker documented for the Docker Compose
target ([`deploy/docker-compose/full-node/README.md`](../../docker-compose/full-node/README.md)):
cdk-erigon v2.61.24 gates L1-only sync behind a sequencer-only flag, so this
role cannot run as an independent full node.

`values.yaml` in this directory has been reduced to an explanatory stub — the
old keys (`config.syncFromL1Only`, `config.l2DatastreamerUrl: ""`,
`config.l1ContractAddressCheck: true`) promised a mode the binary refuses to
run and that the vendored chart doesn't implement, so they were removed.

## What to run instead (today)

For independent state verification without the sequencer-gated L1-only mode,
run **an RPC node + a watchtower**:

- [`deploy/kubernetes/rpc-node`](../rpc-node) — the RPC node re-executes every
  block it receives from the datastream and surfaces a `BadBlock` / state-root
  mismatch in its logs if the sequencer publishes bad state.
- [`deploy/kubernetes/watchtower`](../watchtower) — independently watches the
  L1 RollupManager contract for misbehavior (no chart ships yet; see that
  directory — Docker Compose is the supported path for the watchtower today).

See [`docs/nodes/full-node.md`](../../../docs/nodes/full-node.md) for the trust
tradeoffs.

## Reopening this role

Revisit only against a cdk-erigon build that exposes L1-only sync to
non-sequencer nodes. Re-verify against the exact source lines noted in the
Docker Compose full-node README before adding any flags back here.
