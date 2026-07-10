# chart/files/

Byte-identical mirrors of `configs/dynamic-glassnet-{allocs,conf,chainspec}.json`
(the canonical copies used by every deploy target in this repo — Docker
Compose, systemd, cloud). Helm's `.Files.Get` can only read files that live
inside the chart directory, so these three are vendored here rather than
referenced from `../../../configs/` directly.

`templates/configmap.yaml` embeds each file verbatim (via `.Files.Get`) into
the rendered ConfigMap, keyed as `<config.chainName>-{allocs,conf,chainspec}.json`
— cdk-erigon requires these to sit in the same directory as its `--config`
file, and resolves them by the chain name passed to `--chain` (default here:
`dynamic-glassnet`).

## Keeping these in sync

There is no build step or symlink — if `configs/dynamic-glassnet-*.json`
changes (e.g. a chain reset), re-run:

```bash
deploy/kubernetes/sync-chart-files.sh          # copies + diffs
deploy/kubernetes/sync-chart-files.sh --check  # diff only, non-zero exit on drift
```

Independently verify integrity against the repo-wide checksums:

```bash
cd deploy/kubernetes/chart/files
grep dynamic-glassnet ../../../../configs/CHECKSUMS.txt | sed 's#dynamic-glassnet#dynamic-glassnet#' > /tmp/chk
(cd ../../../../configs && sha256sum -c CHECKSUMS.txt)   # canonical copies
sha256sum dynamic-glassnet-*.json                        # compare by eye, or:
deploy/kubernetes/sync-chart-files.sh --check
```
