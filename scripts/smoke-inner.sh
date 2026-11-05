#!/bin/sh
# Runs inside the image under test (started with --network none by smoke-test.sh).
# Starts qBittorrent the way the entrypoint does, from the bundled qBittorrent.conf,
# with the interface and port settings the entrypoint writes, then checks it through
# the Web API. Usage: smoke-inner.sh EXPECTED_QBITTORRENT EXPECTED_LIBTORRENT
set -eu
want_qbt=$1
want_lt=$2
P=/tmp/smoke
CONF=$P/qBittorrent/config/qBittorrent.conf
URL=http://127.0.0.1:8888

mkdir -p "$P/qBittorrent/config"
sed -e 's/^Session\\Interface=.*/Session\\Interface=lo/' \
    -e 's/^Session\\InterfaceName=.*/Session\\InterfaceName=lo/' \
    -e 's/^Session\\Port=.*/Session\\Port=45678/' \
    /app/qBittorrent.conf > "$CONF"
chown -R qbtUser "$P"
doas -u qbtUser sh -c "exec qbittorrent-nox --webui-port=8888 --profile=$P" > "$P/out.log" 2>&1 &

pw=""
i=0
while [ $i -lt 60 ]; do
  pw=$(sed -n 's/.*temporary password is provided for this session: \([^ ]*\).*/\1/p' "$P/out.log" | tail -1)
  [ -n "$pw" ] && curl -s -o /dev/null "$URL/" && break
  sleep 2
  i=$((i + 1))
done
if [ -z "$pw" ]; then
  echo "FAIL: qBittorrent did not start"
  cat "$P/out.log"
  exit 1
fi

J=$P/cookies
# Success is HTTP 200 "Ok." (older qBittorrent) or 204 with no body (5.3+), plus a
# session cookie either way.
code=$(curl -s -o /dev/null -w '%{http_code}' -c "$J" -e "$URL" \
  --data-urlencode "username=admin" --data-urlencode "password=$pw" "$URL/api/v2/auth/login")
if ! { [ "$code" = 200 ] || [ "$code" = 204 ]; } || ! grep -q QBT_SID "$J"; then
  echo "FAIL: Web UI login (HTTP $code, session cookie: $(grep -c QBT_SID "$J" || true))"
  exit 1
fi
echo "ok   Web UI login (HTTP $code)"

fail=0
check() { # label expected actual
  if [ "$2" = "$3" ]; then
    echo "ok   $1: $3"
  else
    echo "FAIL $1: expected '$2', got '$3'"
    fail=1
  fi
}
check "qBittorrent version" "v$want_qbt" "$(curl -s -b "$J" -e "$URL" "$URL/api/v2/app/version")"
lt=$(curl -s -b "$J" -e "$URL" "$URL/api/v2/app/buildInfo" | jq -r '.libtorrent // empty')
case "$lt" in
  "$want_lt"|"$want_lt".*) echo "ok   libtorrent: $lt" ;;
  *) echo "FAIL libtorrent: expected '$want_lt', got '$lt'"; fail=1 ;;
esac
prefs=$(curl -s -b "$J" -e "$URL" "$URL/api/v2/app/preferences")
check "network interface setting" "lo" "$(echo "$prefs" | jq -r '.current_network_interface // empty')"
check "listening port setting" "45678" "$(echo "$prefs" | jq -r '.listen_port // empty')"
exit $fail
