#!/bin/sh
# Tunnel-liveness thresholds, shared by entrypoint.sh and healthcheck.sh.
#
# These lived as four literals across two files. They are deliberately different,
# not accidentally so, and keeping the reasons next to each other is the point of
# this file - a cross-reference comment had already drifted ("keep all three in
# step" when there were four) one commit after the values were written.
#
# The loop values are tighter because entrypoint.sh acts on them itself and can
# retry; the healthcheck values are looser because Docker retries the check 3x
# before marking the container unhealthy, and because a container wrongly reported
# unhealthy can be restarted by an orchestrator with no further judgement applied.

# WireGuard handshake age. PersistentKeepalive is 25s, so a healthy tunnel is never
# anywhere near these; the slack is for rekey jitter and for an in-progress
# reconnect that is about to succeed.
WG_STALE_LOOP=150       # entrypoint.sh tunnel_alive()
WG_STALE_HEALTH=180     # healthcheck.sh

# OpenVPN --status file age. Rewritten every 10s, so staleness means the process is
# wedged rather than merely present.
OVPN_STATUS_LOOP=120    # entrypoint.sh tunnel_alive()
OVPN_STATUS_HEALTH=180  # healthcheck.sh
