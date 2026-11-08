<p align="center"><img src="https://raw.githubusercontent.com/GeorgeAL78/pia-qbittorrent-docker/master/readme/icon.png" width="130" alt="pia-qbittorrent logo"></p>

<h1 align="center">qBittorrent + Private Internet Access VPN</h1>

<table>
<thead><tr><th>Release</th><th>qBittorrent</th><th>Docker</th></tr></thead>
<tbody>
<tr><td><a href="https://github.com/GeorgeAL78/pia-qbittorrent-docker/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/GeorgeAL78/pia-qbittorrent-docker?label=latest%20release"></a></td><td><a href="https://github.com/qbittorrent/qBittorrent/releases"><img alt="qBittorrent" src="https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fraw.githubusercontent.com%2FGeorgeAL78%2Fpia-qbittorrent-docker%2Fmaster%2FDockerfile&search=release-%28%5Cd%2B%5C.%5Cd%2B%5C.%5Cd%2B%29&replace=%241&label=qBittorrent%20stable&color=2186c4&logo=qbittorrent"></a></td><td><a href="https://hub.docker.com/r/gjergjk/pia-qbittorrent"><img alt="Docker Pulls" src="https://img.shields.io/docker/pulls/gjergjk/pia-qbittorrent?logo=docker"></a></td></tr>
<tr><td><a href="https://github.com/GeorgeAL78/pia-qbittorrent-docker/releases?q=prerelease%3Atrue&expanded=true"><img alt="Beta" src="https://img.shields.io/github/v/release/GeorgeAL78/pia-qbittorrent-docker?include_prereleases&filter=*beta*&label=beta&color=orange"></a></td><td><a href="https://github.com/qbittorrent/qBittorrent/releases"><img alt="qBittorrent beta" src="https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fraw.githubusercontent.com%2FGeorgeAL78%2Fpia-qbittorrent-docker%2Fbeta%2FDockerfile&search=release-%28%5B0-9A-Za-z.%5D%2B%29&replace=%241&label=qBittorrent%20beta&color=orange&logo=qbittorrent"></a></td><td><a href="https://hub.docker.com/r/gjergjk/pia-qbittorrent/tags"><img alt="Image Size" src="https://img.shields.io/docker/image-size/gjergjk/pia-qbittorrent/latest?logo=docker&label=image%20size"></a></td></tr>
<tr><td><a href="https://github.com/GeorgeAL78/pia-qbittorrent-docker/releases/latest"><img alt="Release date" src="https://img.shields.io/github/release-date/GeorgeAL78/pia-qbittorrent-docker"></a></td><td></td><td><a href="https://github.com/GeorgeAL78/pia-qbittorrent-docker/blob/master/LICENSE"><img alt="License" src="https://img.shields.io/github/license/GeorgeAL78/pia-qbittorrent-docker"></a></td></tr>
</tbody>
</table>

qBittorrent routed through a Private Internet Access VPN tunnel, with a kill switch that blocks all traffic if the VPN drops. Supports both WireGuard and OpenVPN, on Alpine Linux for a small image.

The container is designed to look after itself: if the tunnel dies it reconnects in place, fails over to another server in your region if one goes down, and restarts itself as a last resort.

**Source:** [github.com/GeorgeAL78/pia-qbittorrent-docker](https://github.com/GeorgeAL78/pia-qbittorrent-docker)

## Quick Start

> **Requires an active PIA subscription.** [Get one here](https://www.privateinternetaccess.com/pages/buy-a-vpn/1218buyavpn?conversionpoint=RaFInv_30d&invite=U2FsdGVkX18J1Nv81yTCd-NGcpwQ2M61ZrdiLLbhR3g%2C1nufXzgd9Qroyu8zAyDLK2baD5w) — that is a referral link, which supports this project at no extra cost to you.

```bash
docker run -d \
  --name pia-qbittorrent \
  --cap-add=NET_ADMIN \
  --restart unless-stopped \
  -e PIA_USERNAME=your_username \
  -e PIA_PASSWORD=your_password \
  -e PIA_REGION=ca_montreal \
  -e VPN_CLIENT=wireguard \
  -p 8888:8888 \
  -v /your/downloads:/downloads \
  -v /your/config:/config \
  gjergjk/pia-qbittorrent:latest
```

Then open the Web UI on port `8888`. `--cap-add=NET_ADMIN` is required (the VPN and kill switch need it) and `--restart unless-stopped` is strongly recommended so the container can restart itself to recover from an expired VPN token.

## Features

- **Your real IP stays hidden** - if the VPN drops, the container loses its internet instead of quietly falling back to your normal connection
- **It fixes itself** - it notices when the VPN has stopped working - including when it still looks connected - and repairs it without you doing anything
- **A dead VPN server is not your problem** - it moves to another server nearby, and your forwarded port moves with it
- **It keeps up with PIA** - the list of PIA servers is refreshed every time the container starts, so it still works when PIA moves a region onto new machines
- **Faster seeding** - PIA port forwarding is set up for you, wherever your region supports it
- **Downloads survive updates** - it saves your progress on shutdown, so nothing re-checks after a restart
- **Files land with the right owner** - so they are readable on Unraid and other NAS systems without fixing permissions afterwards
- **Your PIA login can stay out of the container settings** - keep it in a protected file instead
- **Runs on a Raspberry Pi** - as well as a normal PC or server

**Under the hood**

**VPN and privacy**
- WireGuard and OpenVPN support, using PIA's next-gen servers
- Kill switch: all IPv4 and IPv6 traffic is blocked if the VPN drops
- DNS leak protection with configurable DNS servers
- Credentials can be supplied via a protected `auth.conf` file instead of environment variables

**Reliability**
- Reconnects in place when the tunnel drops, without restarting the container
- Fails over to another server in your region if one goes down, at startup and on reconnect - port forwarding follows the move
- Retries port forwarding in the background if PIA cannot provide a port at startup, and switches qBittorrent to it once it works
- Detects a tunnel that has silently stopped passing traffic and repairs it
- Relaunches qBittorrent after a reconnect so it picks up the new tunnel address. Resume data is saved first
- Docker healthcheck reports `unhealthy` when the tunnel is up but dead, so orchestrators and restart-on-unhealthy setups can act on it
- Restarts itself if in-place recovery cannot fix the problem
- Graceful shutdown saves resume data, so torrents do not re-check after an update

**qBittorrent**
- PIA port forwarding for better seeding, where the region supports it
- TCP peer connections by default, which is significantly more stable over WireGuard
- Automatic `.torrent` export to `/downloads/torrents`
- Configurable UID/GID and UMASK for correct file ownership on Unraid and NAS systems

**Other**
- Multi-arch: `amd64` and `arm64`
- PIA server list refreshed at every container start as well as at image build time, so a running container tracks PIA's current servers. Falls back to the bundled copy if PIA is unreachable
- Hook script support after the VPN connects, run as the container user

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PIA_USERNAME` | | PIA account username |
| `PIA_PASSWORD` | | PIA account password |
| `PIA_REGION` | `netherlands` | VPN region (see below) |
| `VPN_CLIENT` | `openvpn` | `openvpn` or `wireguard` |
| `PORT_FORWARDING` | `true` | Enable PIA port forwarding for seeding. Skipped automatically in regions that do not support it, and retried in the background if PIA cannot provide a port at startup |
| `UID` | `700` | User ID for the qBittorrent process. Use `99` for Unraid |
| `GID` | `700` | Group ID for the qBittorrent process. Use `100` for Unraid |
| `UMASK` | `022` | Umask for created files. Use `002` for group-writable or `000` for fully open |
| `WEBUI_PORT` | `8888` | Web UI port |
| `WEBUI_INTERFACES` | | Network interfaces the Web UI is reachable on, e.g. `eth0,eth1` |
| `ALLOW_LOCAL_SUBNET_TRAFFIC` | `false` | Allow LAN devices to connect directly to the container |
| `EXTRA_SUBNETS` | | Extra subnets allowed through the kill switch, comma-separated (e.g. for a reverse proxy or *arr apps on another Docker network) |
| `OPEN_ADDITIONAL_LOCAL_PORTS` | | Extra LAN ports to open, comma-separated, e.g. `8989,7878`. For containers routed through this one (`network_mode: container:...`) whose web UI would otherwise be blocked by the kill switch |
| `DNS_SERVERS` | `9.9.9.9,149.112.112.112` | DNS servers, comma-separated |
| `LEGACY_IPTABLES` | `false` | Use legacy iptables instead of nftables |
| `VPN_LOG_DIR` | `/logs` | Where the VPN client writes its log. Must be root-owned; a path under `/config` or a world-writable directory is ignored with a warning |
| `TZ` | | Timezone, e.g. `America/Toronto` |
| `HOSTHEADERVALIDATION` | | Set to `false` if a reverse proxy prevents Web UI access |
| `CSRFPROTECTION` | | Set to `false` if a reverse proxy prevents Web UI access |

## PIA Regions

Set `PIA_REGION` to the region you want. Matching is flexible: use the region name or its PIA ID, case-insensitive, so `ca_montreal`, `CA Montreal` and `ca` all resolve to the same region.

Popular regions with port forwarding:

| `PIA_REGION` | Location |
|--------------|----------|
| `ca_montreal` | CA Montreal |
| `netherlands` | Netherlands |
| `de_frankfurt` | DE Frankfurt |
| `uk` | UK London |
| `sweden` | SE Stockholm |
| `switzerland` | Switzerland |
| `france` | France |
| `singapore` | Singapore |
| `japan` | JP Tokyo |
| `aus` | AU Sydney |

**135 of PIA's 190 regions support port forwarding, and no US region does.** Pick a non-US region if port forwarding matters to you; the container skips it automatically otherwise. [Full list](https://github.com/GeorgeAL78/pia-qbittorrent-docker#pia-regions).

The container refreshes this list from PIA on every start, so it is not limited to the counts above.

## Volumes and Ports

| Volume | Description |
|--------|-------------|
| `/downloads` | Download directory |
| `/config` | qBittorrent config and profiles |

| Port | Description |
|------|-------------|
| `8888` | Web UI (configurable via `WEBUI_PORT`) |

## Unraid

Available in **Community Applications**: search for `pia-qbittorrent`.

- **File ownership:** set `UID=99` and `GID=100` to match Unraid's `nobody:users`, and `UMASK=000` (or `002`) so other users can manage the files.
- **Storage:** map `/downloads` to your share (e.g. `/mnt/user/downloads/`) and `/config` to appdata (e.g. `/mnt/user/appdata/pia-qbittorrent/`).
- **Network:** Bridge and custom bridge networks both work; the VPN tunnel runs inside the container either way. Avoid **Host** networking: the container would then share the Unraid server's own network stack, so the kill switch's firewall rules, routes and IPv6 settings would be applied to the server — including flushing the iptables rules Docker itself relies on, which breaks networking for other containers.
- **Extra Parameters:** keep `--cap-add=NET_ADMIN --restart unless-stopped`.
- **Other containers** (Sonarr, Radarr, etc.): if they are on a different Docker network and cannot reach the Web UI, add their subnet to `EXTRA_SUBNETS`, e.g. `172.18.0.0/16`.

## Companion App

[qBittorrent Desktop for Windows 11](https://github.com/GeorgeAL78/qbittorrent-desktop) is an optional native wrapper for the Web UI, with system tray, magnet link handling, `.torrent` file association, and the running container version in the title bar.

## Components

| Component | Stable (`latest`) | Beta (`beta`) |
|-----------|---------|---------|
| Alpine Linux | 3.24 | same |
| qBittorrent | 5.3.0 | same |
| libtorrent | 2.1.2 | same |
| Boost | 1.92.0 | same |
| Python 3 | Alpine 3.24 default (required by qBittorrent search plugins) | same |

## Versioning

Image tags follow the bundled qBittorrent version. Fixes released between qBittorrent versions use a numbered suffix, for example `5.3.0-1`, `5.3.0-2`. Use `latest` for the newest build, or pin to a specific tag. `beta` holds the newest build of the next qBittorrent pre-release, or the same release as `latest` when there is none, and never replaces `latest`; past betas are listed as pre-releases on [GitHub](https://github.com/GeorgeAL78/pia-qbittorrent-docker/releases).

## What's new

**5.3.0-2** (latest)
- Fixed: the version header and the HOSTHEADERVALIDATION and CSRFPROTECTION settings apply again on configs saved by qBittorrent 5.3.

### Recent highlights

**Recovers on its own, quickly**
- Notices a dead VPN within about a minute and reconnects without restarting the container
- Moves to another PIA server if yours goes down, and keeps your forwarded port
- Keeps retrying port forwarding if PIA refuses it at startup, without touching the VPN
- Rides out brief blips and modem reboots instead of overreacting to them
- Keeps your torrents connected when the tunnel reconnects

**Always current with PIA**
- Refreshes PIA's server list every time it starts, so it keeps working as PIA rotates servers
- Signs in through PIA's current login service

**Tighter security**
- The kill switch has no open moment during startup
- The Web UI port is open for incoming connections only, never as a way out
- IPv6 is blocked — or the container refuses to start rather than leak
- Port-forward requests are verified against PIA's certificate authority
- Custom hook scripts run without root access

**Lighter**
- 21% smaller image — 269 MB down to 213 MB

Full release history is on [GitHub](https://github.com/GeorgeAL78/pia-qbittorrent-docker/releases).

## License

[GNU General Public License v3.0](https://github.com/GeorgeAL78/pia-qbittorrent-docker/blob/master/LICENSE). A fork of [j4ym0/pia-qbittorrent](https://hub.docker.com/r/j4ym0/pia-qbittorrent), originally MIT licensed.

## Disclaimer

Not affiliated with, endorsed by, or sponsored by Private Internet Access, Kape Technologies, or the qBittorrent project. "Private Internet Access" and "qBittorrent" are trademarks of their respective owners. Provided as-is, with no warranty. You are responsible for complying with the laws in your jurisdiction and with your VPN provider's terms of service.
