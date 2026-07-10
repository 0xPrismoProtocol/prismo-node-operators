#!/usr/bin/env bash
# Download + verify a Prismo data-dir snapshot, then extract.
# Usage: ./verify-snapshot.sh <url> <sha256> <dest_dir>
set -euo pipefail
URL="${1:?snapshot URL required}"
SHA="${2:?expected sha256 required}"
DEST="${3:?destination dir required}"

mkdir -p "$DEST"
TMP="$(mktemp -t prismo-snap.XXXXXX.tar.zst)"
trap 'rm -f "$TMP"' EXIT

echo "Downloading $URL ..."
curl -fSL --retry 3 "$URL" -o "$TMP"

echo "Verifying SHA-256 ..."
echo "$SHA  $TMP" | sha256sum -c -

echo "Extracting to $DEST ..."
tar --use-compress-program=unzstd -xf "$TMP" -C "$DEST"

echo "Done. Listing $DEST:"
ls -lh "$DEST"
