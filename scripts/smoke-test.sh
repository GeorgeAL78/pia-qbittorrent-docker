#!/bin/sh
# Smoke test for a built image: starts qBittorrent with no network at all (no VPN, no
# PIA login) and checks that it runs, reports the pinned versions and reads the
# settings the entrypoint writes. Usage: smoke-test.sh IMAGE [DOCKERFILE]
set -eu
img=$1
df=${2:-Dockerfile}
here=$(dirname "$0")

qbt=$(sed -n 's#.*qBittorrent/tarball/release-\([^ ]*\) .*#\1#p' "$df")
lt=$(sed -n 's#.*libtorrent/releases/download/v\([0-9.]*\)/.*#\1#p' "$df")
[ -n "$qbt" ] && [ -n "$lt" ] || { echo "FAIL: could not read the pins from $df"; exit 1; }
echo "image: $img"
echo "expecting qBittorrent $qbt, libtorrent $lt"

name=smoke-$$
trap 'docker rm -fv "$name" >/dev/null 2>&1 || true' EXIT
docker run -d --name "$name" --network none --entrypoint sleep "$img" 600 >/dev/null
docker cp "$here/smoke-inner.sh" "$name:/tmp/smoke-inner.sh"
docker exec "$name" sh /tmp/smoke-inner.sh "$qbt" "$lt"
