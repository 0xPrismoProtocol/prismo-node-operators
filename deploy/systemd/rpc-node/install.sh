#!/usr/bin/env bash
# Install Prismo RPC node as a systemd service.
# Tested on Ubuntu 22.04+ / Debian 12+.
#
# Usage: NETWORK=testnet sudo bash install.sh   # or NETWORK=mainnet
set -euo pipefail

CDK_VERSION="${CDK_VERSION:-v2.61.24}"
# Pin by digest, not just the mutable tag: a tag can be re-pushed, a digest
# cannot. Extracting the binary + musl loader from a digest-pinned image makes
# the install byte-deterministic. This is the index (multi-arch) manifest digest
# for v2.61.24, verified against ghcr.io/0xpolygon/cdk-erigon on 2026-07-20.
CDK_DIGEST_DEFAULT="sha256:cf93eff2be9744e12b0ce96ba48c9fe43b30e44a1f9f54f3a34d4039f363b2ab"
# The pinned digest only applies to the default version. If you bump
# CDK_VERSION, pass a matching CDK_DIGEST=sha256:... (get it via
# `docker buildx imagetools inspect ghcr.io/0xpolygon/cdk-erigon:<ver>`);
# otherwise the install proceeds by mutable tag with a warning.
if [[ "$CDK_VERSION" == "v2.61.24" ]]; then
  CDK_DIGEST="${CDK_DIGEST:-$CDK_DIGEST_DEFAULT}"
else
  CDK_DIGEST="${CDK_DIGEST:-}"
fi
if [[ -n "$CDK_DIGEST" ]]; then
  CDK_IMAGE="ghcr.io/0xpolygon/cdk-erigon@${CDK_DIGEST}"
else
  echo "WARNING: no CDK_DIGEST pinned for $CDK_VERSION — installing by mutable tag (not digest-pinned)." >&2
  CDK_IMAGE="ghcr.io/0xpolygon/cdk-erigon:${CDK_VERSION}"
fi
CDK_MUSL_LIBDIR="/usr/local/lib/cdk-erigon"
NETWORK="${NETWORK:-testnet}"

require_root() { [[ $EUID -eq 0 ]] || { echo "run as root"; exit 1; }; }
require_root

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NET_FILE="$SCRIPT_DIR/../../../configs/networks/${NETWORK}.env"
[[ -f "$NET_FILE" ]] || { echo "unknown NETWORK=$NETWORK (no $NET_FILE)"; exit 1; }

# 1. user
id prismo &>/dev/null || useradd --system --home /var/lib/prismo --shell /usr/sbin/nologin prismo

# 2. dirs
install -d -o prismo -g prismo -m 0750 /var/lib/prismo /var/lib/prismo/data
install -d                     -m 0755 /etc/prismo

# 3. binary — no standalone release binaries are published for cdk-erigon, so
# the pinned binary is extracted from the ghcr image instead. docker is only
# needed here, at install time; the running service stays containerless.
command -v docker &>/dev/null || {
  echo "docker is required at install time to extract the pinned binary; the runtime itself stays containerless" >&2
  exit 1
}

echo "Extracting cdk-erigon ${CDK_VERSION} from ${CDK_IMAGE} ..."
CID="$(docker create "$CDK_IMAGE")"

docker cp "$CID:/usr/local/bin/cdk-erigon" /usr/local/bin/cdk-erigon

# cdk-erigon is musl-linked (built on Alpine) — a glibc host like Ubuntu/Debian
# has no /lib/ld-musl-x86_64.so.1 interpreter, and the distro's own libstdc++6
# is glibc-ABI and fails to resolve symbols under musl. Pull the loader and the
# matching C++ runtime from the same image rather than the host package
# manager, so the exact ABI the binary was linked against is what runs it.
install -d -m 0755 "$CDK_MUSL_LIBDIR"
LIBSTDCPP_REAL="$(docker run --rm --entrypoint sh "$CDK_IMAGE" -c 'basename "$(readlink -f /usr/lib/libstdc++.so.6)"')"
docker cp "$CID:/lib/ld-musl-x86_64.so.1" /lib/ld-musl-x86_64.so.1
docker cp "$CID:/usr/lib/$LIBSTDCPP_REAL" "$CDK_MUSL_LIBDIR/$LIBSTDCPP_REAL"
docker cp "$CID:/usr/lib/libgcc_s.so.1" "$CDK_MUSL_LIBDIR/libgcc_s.so.1"
ln -sf "$LIBSTDCPP_REAL" "$CDK_MUSL_LIBDIR/libstdc++.so.6"

docker rm "$CID" >/dev/null

chmod +x /lib/ld-musl-x86_64.so.1 /usr/local/bin/cdk-erigon

echo -n "Verifying extracted binary: "
LD_LIBRARY_PATH="$CDK_MUSL_LIBDIR" /usr/local/bin/cdk-erigon --version

# 4. config: network-agnostic yaml + per-network env
install -m 0644 "$SCRIPT_DIR/../../../configs/chain-config.yaml" /etc/prismo/chain-config.yaml
# Chain files MUST sit next to chain-config.yaml — cdk-erigon resolves
# dynamic-<chain>-*.json relative to the --config file's directory. Globbing
# dynamic-*.json (not just dynamic-glassnet-*.json) means mainnet's chain
# files land here automatically once they're committed, with no script change.
install -m 0644 "$SCRIPT_DIR"/../../../configs/dynamic-*.json /etc/prismo/
install -m 0644 "$NET_FILE" /etc/prismo/network.env

# Operator-editable env (L1_RPC_URL + any overrides). This wins over network.env
# at unit start time via two EnvironmentFile= lines (later overrides earlier).
if [[ ! -f /etc/prismo/env ]]; then
  cat > /etc/prismo/env <<EOF
# Active network for this host. Must match /etc/prismo/network.env.
NETWORK=${NETWORK}

# Required: L1 RPC URL.
#   testnet: a Sepolia endpoint
#   mainnet: an Ethereum endpoint
L1_RPC_URL=https://your-l1-provider.example/your-key

# Optional overrides:
# DATASTREAM_HOST=
# DATASTREAM_PORT=
EOF
  chmod 0640 /etc/prismo/env
  chown root:prismo /etc/prismo/env
fi

# 5. unit
install -m 0644 "$SCRIPT_DIR/cdk-erigon.service" /etc/systemd/system/cdk-erigon.service
systemctl daemon-reload

echo
echo "Installed for NETWORK=$NETWORK."
echo "Edit /etc/prismo/env (set L1_RPC_URL), then:"
echo "  systemctl enable --now cdk-erigon"
echo "  journalctl -u cdk-erigon -f"
echo
echo "To switch networks later:"
echo "  NETWORK=mainnet bash $0   # re-runs with the other network env"
