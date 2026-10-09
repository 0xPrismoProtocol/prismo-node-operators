# chart/files/

Byte-identical mirrors of the chain-file sets in `configs/`:

| Network | `config.chainName` | Files |
|---|---|---|
| testnet (Glassnet, 101001000) | `dynamic-glassnet` | `dynamic-glassnet-{allocs,conf,chainspec}.json` |
| mainnet (Prismo Glass, 328) | `dynamic-glass` | `dynamic-glass-{allocs,conf,chainspec}.json` |

These are the canonical copies used by every deploy target in this repo
(Docker Compose, systemd, cloud). Helm's `.Files.Get` can only read files
that live inside the chart directory, so they are vendored here rather than
referenced from `../../../configs/` directly.

`templates/configmap.yaml` embeds the set selected by `config.chainName`
verbatim into the rendered ConfigMap, keyed as
`<config.chainName>-{allocs,conf,chainspec}.json` — cdk-erigon requires
these to sit in the same directory as its `--config` file, and resolves them
by the chain name passed to `--chain`. A `chainName` with no complete set
here fails the render (`helm template` / `helm install` error) instead of
booting a node with an empty genesis.

## Keeping these in sync

There is no build step or symlink — if any `configs/dynamic-*.json` changes
(a chain reset, or a new network), re-run:

```bash
deploy/kubernetes/sync-chart-files.sh          # copies + diffs every set
deploy/kubernetes/sync-chart-files.sh --check  # diff only, non-zero exit on drift
```

Independently verify integrity against the repo-wide checksums:

```bash
(cd configs && sha256sum -c CHECKSUMS.txt)     # canonical copies
deploy/kubernetes/sync-chart-files.sh --check   # chart copies == canonical, and
                                                 # chart copies match CHECKSUMS.txt
```
