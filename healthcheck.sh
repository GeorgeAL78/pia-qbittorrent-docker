#!/bin/sh

# Check the VPN interface exists
if ! ifconfig | grep -qE 'tun[0-9]|tap[0-9]|pia'; then
    echo "No VPN interface found" >&2
    exit 1
fi

# The interface existing does not mean the tunnel is alive - WireGuard leaves it
# up even after the peer stops responding, which is exactly the failure where
# torrents hang with no error. For WireGuard, check handshake freshness: a local
# read, no network traffic generated. PersistentKeepalive is 25s, so a healthy
# tunnel's handshake is never old; 180s allows for rekey jitter and for an
# in-progress reconnect that is about to succeed.
if ifconfig | grep -q 'pia'; then
    HS=$(wg show pia latest-handshakes 2>/dev/null | awk 'NR==1{print $2}')
    if [ -n "$HS" ] && [ "$HS" -gt 0 ] 2>/dev/null; then
        AGE=$(( $(date +%s) - HS ))
        if [ "$AGE" -ge 180 ]; then
            echo "VPN tunnel is stale - last WireGuard handshake ${AGE}s ago" >&2
            exit 1
        fi
    else
        echo "VPN interface is up but has never completed a handshake" >&2
        exit 1
    fi
fi

# For OpenVPN, the interface and the process both persist when the client wedges,
# so neither proves the tunnel is alive. openvpn is started with --status, which
# rewrites a local file every 10s; a stale file means wedged. Local read, no network.
# Threshold matches the WireGuard branch above (180s) because this check gets the
# same retry budget from Docker; entrypoint.sh uses 150s in its monitoring loop,
# which retries on a different schedule. Keep all three in step if any changes.
if ifconfig | grep -qE 'tun[0-9]|tap[0-9]'; then
    if ! pgrep -x openvpn > /dev/null 2>&1; then
        echo "VPN interface exists but the openvpn process is gone" >&2
        exit 1
    fi
    if [ -f /run/openvpn.status ]; then
        AGE=$(( $(date +%s) - $(stat -c %Y /run/openvpn.status 2>/dev/null || echo 0) ))
        if [ "$AGE" -ge 180 ]; then
            echo "openvpn is running but its status file is ${AGE}s stale - wedged" >&2
            exit 1
        fi
    fi
fi

# Check web UI
HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" --max-time 5 "http://localhost:${WEBUI_PORT}" 2>/dev/null)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
    exit 0
fi

# Retry with HTTPS if HTTP failed
HTTPS_CODE=$(curl -o /dev/null -s -k --max-time 5 "https://localhost:${WEBUI_PORT}" 2>/dev/null)
if [ "$HTTPS_CODE" = "200" ] || [ "$HTTPS_CODE" = "401" ] || [ "$HTTPS_CODE" = "403" ]; then
    exit 0
fi

echo "Web UI not responding on port ${WEBUI_PORT}" >&2
exit 1
