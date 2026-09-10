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

# How long to wait before RETRYING a reconnect that failed. The monitoring loop
# ticks every MONITOR_TICK seconds; after a failure it re-runs sooner than that,
# because a full tick means a path that came back is not noticed for ten minutes
# (measured in production: a 56-minute outage where the path returned at ~04:02 but
# five of the six attempts were spent waiting).
#
# Deliberately NOT ~30s. The exit-5 escalation fires after 6 consecutive failures,
# and startup fetches a PIA token BEFORE building the firewall - aborting with
# exit 3 if that fails. Restarting into a still-dead WAN therefore crash-loops. At
# 30s the six failures land in ~6 minutes, well inside a normal modem reboot; at
# 180s the budget is 6 x (180 + ~60s per attempt) = ~24 minutes, which still
# tolerates an ISP outage.
MONITOR_TICK=600            # entrypoint.sh main loop: seconds between routine checks
RECONNECT_RETRY_GAP=180     # entrypoint.sh: seconds before retrying a FAILED reconnect

# Consecutive failed reconnects before giving up and restarting the container.
#
# This is a TIME budget wearing an attempt count, so it has to move whenever the
# retry gap does. It exists so a modem reboot or a short ISP outage is ridden out in
# place: startup fetches a PIA token BEFORE building the firewall and aborts with
# exit 3 if it cannot, so restarting into a still-dead WAN crash-loops.
#
# The old pairing was 6 failures roughly 11 minutes apart, i.e. ~57 minutes of
# tolerance. Shortening the gap to 180s without touching this count would have cut
# that to ~22 minutes and turned a 40-minute ISP outage into a restart - a
# regression in exactly the case the budget protects. 15 at the new cadence is
# ~58 minutes, preserving the original tolerance while retrying every ~4 minutes.
#
#   tolerance ~= 36s (sampler confirm) + 60s + (N-1) x (RECONNECT_RETRY_GAP + 60s)
RECONNECT_MAX_FAILURES=15   # entrypoint.sh: ~58 min at a 180s gap
