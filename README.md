<div align="center">

<img src="readme/icon.png" width="120" alt="pia-qbittorrent logo">

## qBittorrent & Private Internet Access VPN Docker

[![CI](https://img.shields.io/github/actions/workflow/status/GeorgeAL78/pia-qbittorrent-docker/docker-publish.yml?label=CI&logo=github)](https://github.com/GeorgeAL78/pia-qbittorrent-docker/actions)
[![License](https://img.shields.io/github/license/GeorgeAL78/pia-qbittorrent-docker)](LICENSE)
[![qBittorrent](https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fraw.githubusercontent.com%2FGeorgeAL78%2Fpia-qbittorrent-docker%2Fmaster%2FDockerfile&search=release-%28%5Cd%2B%5C.%5Cd%2B%5C.%5Cd%2B%29&replace=%241&label=qBittorrent&color=2186c4&logo=qbittorrent)](https://github.com/qbittorrent/qBittorrent/releases)
[![Unraid CA](https://img.shields.io/badge/Unraid-Community%20Apps-orange)](https://ca.unraid.net/apps/search?query=pia-qbittorrent)

[![Docker Pulls](https://img.shields.io/docker/pulls/gjergjk/pia-qbittorrent?logo=docker)](https://hub.docker.com/r/gjergjk/pia-qbittorrent)
[![Docker Stars](https://img.shields.io/docker/stars/gjergjk/pia-qbittorrent?logo=docker)](https://hub.docker.com/r/gjergjk/pia-qbittorrent)
[![Image Size](https://img.shields.io/docker/image-size/gjergjk/pia-qbittorrent/latest?logo=docker&label=image%20size)](https://hub.docker.com/r/gjergjk/pia-qbittorrent/tags)

[![Latest Tag](https://img.shields.io/github/v/tag/GeorgeAL78/pia-qbittorrent-docker?label=latest%20release)](https://github.com/GeorgeAL78/pia-qbittorrent-docker/releases)
[![Release Date](https://img.shields.io/github/release-date/GeorgeAL78/pia-qbittorrent-docker)](https://github.com/GeorgeAL78/pia-qbittorrent-docker/releases)
[![Commits Since](https://img.shields.io/github/commits-since/GeorgeAL78/pia-qbittorrent-docker/latest)](https://github.com/GeorgeAL78/pia-qbittorrent-docker/commits/master)
[![Last Commit](https://img.shields.io/github/last-commit/GeorgeAL78/pia-qbittorrent-docker)](https://github.com/GeorgeAL78/pia-qbittorrent-docker/commits/master)

[![Open Issues](https://img.shields.io/github/issues/GeorgeAL78/pia-qbittorrent-docker)](https://github.com/GeorgeAL78/pia-qbittorrent-docker/issues)
[![Code Size](https://img.shields.io/github/languages/code-size/GeorgeAL78/pia-qbittorrent-docker)](https://github.com/GeorgeAL78/pia-qbittorrent-docker)
[![Repo Size](https://img.shields.io/github/repo-size/GeorgeAL78/pia-qbittorrent-docker)](https://github.com/GeorgeAL78/pia-qbittorrent-docker)
[![Top Language](https://img.shields.io/github/languages/top/GeorgeAL78/pia-qbittorrent-docker)](https://github.com/GeorgeAL78/pia-qbittorrent-docker)

</div>

A Docker container combining **qBittorrent** with **Private Internet Access (PIA) VPN**, supporting both **WireGuard** and **OpenVPN**. Built on Alpine Linux for a minimal footprint.

> Fork of [j4ym0/pia-qbittorrent](https://hub.docker.com/r/j4ym0/pia-qbittorrent) with bug fixes and additional features.

## Quick Links

| | | |
|---|---|---|
| 🚀 [Quick Start](#quick-start) | ⚙️ [Environment Variables](#environment-variables) | 🌍 [PIA Regions](#pia-regions) |
| 🔀 [Port Forwarding](#port-forwarding) | 🌐 [VPN Client](#vpn-client) | 🧭 [DNS Servers](#dns-servers) |
| 🖥️ [Unraid Setup](#unraid-setup) | 🔐 [auth.conf File](#authconf-file) | 🪝 [Hooks](#hooks) |
| 💾 [Saving .torrent Files](#saving-torrent-files) | 🧩 [Companion App](#companion-app) | ❓ [Known Issues](#known-issues) |
| 🐛 [Report a Bug](https://github.com/GeorgeAL78/pia-qbittorrent-docker/issues) | 📦 [Releases](https://github.com/GeorgeAL78/pia-qbittorrent-docker/releases) | 🐳 [Docker Hub](https://hub.docker.com/r/gjergjk/pia-qbittorrent) |

---

## Companion App

Looking for a native Windows desktop experience? Check out the companion Electron app that wraps the qBittorrent Web UI:

**[qBittorrent Desktop for Windows 11](https://github.com/GeorgeAL78/qbittorrent-desktop)** — native window, system tray, magnet link support, `.torrent` file association, and the running container version shown in the title bar.

The title-bar version comes from an `X-Docker-Version` response header this image adds to the Web UI (set from the image version on every start), so the app always shows which build is running.

---

## Features

- WireGuard and OpenVPN support
- PIA port forwarding for seeding
- PIA server list fetched directly from PIA at build time — every image ships with the current region list
- Kill switch — all IPv4 and IPv6 traffic blocked if the VPN drops
- Auto-healing VPN — detects a dead/dropped tunnel and reconnects in place (WireGuard re-registers its key, OpenVPN restarts the client and re-authenticates), escalating to a full container restart if the in-place reconnect can't recover it
- Automatic server failover — if the VPN server you're on goes down, reconnect tries the other servers in your region instead of retrying a dead one
- Multi-arch images — `amd64` and `arm64`
- VPN network interface auto-detected and locked (WireGuard `pia` / OpenVPN `tun0`)
- Configurable UID/GID for correct file ownership on Unraid and NAS systems
- Configurable UMASK; download folder permissions preserved across restarts
- Automatic `.torrent` file export to `/downloads/torrents`
- Graceful shutdown — saves resume data so torrents resume instead of re-checking after an update
- Secure credential storage via `auth.conf`
- DNS leak protection with custom DNS servers
- Hook script support after the VPN connects
- Web UI accessible on your local network

---

## Components

| Component | Version |
|-----------|---------|
| Alpine Linux | 3.24 |
| qBittorrent | 5.2.3 |
| libtorrent | 2.0.14 |
| Boost | 1.92.0 |
| OpenVPN | 2.7.5 |
| WireGuard | 1.0.20260223 |
| IPTables | 1.8.13 |
| Python 3 | Alpine 3.24 default |

> **Note on Python:** `python3` is in the runtime image because qBittorrent's
> search plugins require it. With `ack` and `perl` removed in v5.2.3-13 it is now
> the largest optional component left, so it is an obvious target for a future
> size pass - removing it would silently break the Search tab.

---

## Quick Start

```bash
docker run -d --init --name=pia-qbittorrent --restart unless-stopped \
  --cap-add=NET_ADMIN \
  -v /your/downloads:/downloads \
  -v /your/config:/config \
  -p 8888:8888 \
  -e PIA_USERNAME=your_username \
  -e PIA_PASSWORD=your_password \
  -e PIA_REGION=ca_montreal \
  -e VPN_CLIENT=wireguard \
  -e UID=99 \
  -e GID=100 \
  -e UMASK=000 \
  gjergjk/pia-qbittorrent:latest
```

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PIA_USERNAME` | | PIA account username |
| `PIA_PASSWORD` | | PIA account password |
| `PIA_REGION` | `netherlands` | VPN region — see [PIA Servers](#pia-regions) |
| `VPN_CLIENT` | `openvpn` | VPN client: `openvpn` or `wireguard` |
| `PORT_FORWARDING` | `true` | Enable PIA port forwarding for seeding. Falls back gracefully if your region doesn't support it |
| `UID` | `700` | User ID for qBittorrent process. Use `99` for Unraid |
| `GID` | `700` | Group ID for qBittorrent process. Use `100` for Unraid |
| `UMASK` | `022` | Umask for downloads. `000` = fully open, `002` = group-writable |
| `WEBUI_PORT` | `8888` | qBittorrent Web UI port |
| `WEBUI_INTERFACES` | | Network interfaces for Web UI access e.g. `eth0,eth1` |
| `ALLOW_LOCAL_SUBNET_TRAFFIC` | `false` | Allow LAN devices to connect directly to the container |
| `EXTRA_SUBNETS` | | Comma-separated extra subnets to allow through the kill switch (e.g. for reverse proxies or *arr apps on a different Docker network) |
| `OPEN_ADDITIONAL_LOCAL_PORTS` | | Comma-separated extra LAN ports to open, e.g. `8989,7878`. For containers sharing this container's network (`network_mode: container:...`) whose web UIs would otherwise be blocked by the kill switch |
| `DNS_SERVERS` | `9.9.9.9,149.112.112.112` | Comma-separated DNS servers |
| `LEGACY_IPTABLES` | `false` | Use legacy iptables instead of nftables |
| `VPN_LOG_DIR` | `/logs` | Where the VPN client writes its log. Must be root-owned: the port-forward hostname is read from this log and startup aborts on errors found in it, so a directory the container user can write is refused. A path under `/config` (or any world-writable directory) is **ignored with a warning and `/logs` is used instead** |
| `TZ` | | Timezone e.g. `America/New_York` |
| `HOSTHEADERVALIDATION` | | Set to `false` if having trouble accessing the WebUI. Note that the bundled config sets `WebUI\ServerDomains=*` so the container is reachable by any IP or hostname — which means host header validation accepts everything and this setting has no practical effect. **CSRF protection is what actually guards the Web UI.** To make it meaningful, set `WebUI\ServerDomains` to your own hostname in `/config/qBittorrent/config/qBittorrent.conf` |
| `CSRFPROTECTION` | | Set to `false` if having trouble accessing the WebUI |

---

## Volumes

| Path | Description |
|------|-------------|
| `/downloads` | Download directory |
| `/config` | qBittorrent config and profiles |

---

## Unraid Setup

Set the following container variables for correct file ownership:

| Variable | Value |
|----------|-------|
| `UID` | `99` |
| `GID` | `100` |
| `UMASK` | `000` |

This maps qBittorrent to Unraid's `nobody:users` so downloaded files are accessible from SMB shares.

**Network type:** leave it on **Bridge** (the Unraid default). The VPN tunnel runs entirely inside the container, so no special network mode is needed.

---

## VPN Client

### WireGuard
- Lower CPU usage and faster speeds due to less overhead
- Requires Linux kernel 5.6+
- Port forwarding works in most regions but may have issues in some
- Best for stable home networks

### OpenVPN
- Broader compatibility
- Better for unusual network configurations or high latency
- More reliable port forwarding

> **Note:** Port forwarding is available in most PIA regions, but not all. See the [PIA Regions](#pia-regions) section for the full list of regions that support it.

---

## PIA Regions

Set `PIA_REGION` to the region you want. Matching is **flexible** — you can use the region name or its PIA ID, and it's case-insensitive (underscores, hyphens, and spaces are treated the same). So `ca_montreal`, `CA Montreal`, and `ca` all resolve to the same region.

Common regions **with port forwarding**:

| `PIA_REGION` | Location |
|--------------|----------|
| `ca_montreal` | CA Montreal |
| `ca_toronto` | CA Toronto |
| `ca_ontario` | CA Ontario |
| `uk` | UK London |
| `netherlands` | Netherlands |
| `de_frankfurt` | DE Frankfurt |
| `france` | France |
| `switzerland` | Switzerland |
| `sweden` | SE Stockholm |
| `spain` | ES Madrid |
| `italy` | IT Milano |
| `romania` | Romania |
| `singapore` | Singapore |
| `japan` | JP Tokyo |
| `aus` | AU Sydney |

> ℹ️ **Most PIA regions support port forwarding, but not all.** The regions listed above are confirmed to support it. To use a different region with `PORT_FORWARDING=true`, see the full list of port-forwarding regions below.

### All port-forwarding regions

<details>
<summary><h3>🌍 &nbsp;Click to view all 135 port-forwarding regions</h3></summary>

| Location | `PIA_REGION` |
|----------|--------------|
| AR Streaming Optimized | `ar-so` |
| AT Streaming Optimized | `at-so` |
| AU Adelaide | `au_adelaide-pf` |
| AU Brisbane | `au_brisbane-pf` |
| AU Melbourne | `aus_melbourne` |
| AU Perth | `aus_perth` |
| AU Sydney | `aus` |
| Albania | `al` |
| Algeria *(geo)* | `dz` |
| Andorra *(geo)* | `ad` |
| Argentina | `ar` |
| Armenia *(geo)* | `yerevan` |
| Australia Streaming Optimized | `au_australia-so` |
| Austria | `austria` |
| BE Streaming Optimized | `be-so` |
| BR Streaming Optimized | `br-so` |
| Bahamas | `bahamas` |
| Bangladesh | `bangladesh` |
| Belgium | `belgium` |
| Bolivia | `bo_bolivia-pf` |
| Bosnia and Herzegovina *(geo)* | `ba` |
| Brazil | `br` |
| Bulgaria | `sofia` |
| CA Montreal | `ca` |
| CA Ontario | `ca_ontario` |
| CA Ontario Streaming Optimized | `ca_ontario-so` |
| CA Toronto | `ca_toronto` |
| CA Vancouver | `ca_vancouver` |
| CH Streaming Optimized | `ch-so` |
| CL Streaming Optimized | `cl-so` |
| Cambodia *(geo)* | `cambodia` |
| Chile | `santiago` |
| China *(geo)* | `china` |
| Colombia | `bogota` |
| Costa Rica | `sanjose` |
| Croatia | `zagreb` |
| Cyprus *(geo)* | `cyprus` |
| Czech Republic | `czech` |
| DE Berlin | `de_berlin` |
| DE Frankfurt | `de-frankfurt` |
| DE Germany Streaming Optimized | `de_germany-so` |
| DK Streaming Optimized | `denmark_2` |
| Denmark | `denmark` |
| ES Madrid | `spain` |
| ES Streaming Optimized | `es-so` |
| ES Valencia | `es-valencia` |
| Ecuador | `ec_ecuador-pf` |
| Egypt *(geo)* | `egypt` |
| Estonia | `ee` |
| FI Helsinki | `fi` |
| FI Streaming Optimized | `fi_2` |
| FR Streaming Optimized | `fr-so` |
| France | `france` |
| Georgia *(geo)* | `georgia` |
| Greece | `gr` |
| Greenland | `greenland` |
| Guatemala | `gt_guatemala-pf` |
| HU Streaming Optimized | `hu-so` |
| Hong Kong *(geo)* | `hk` |
| Hungary | `hungary` |
| IL Israel 2 | `il_israel_2-pf` |
| IL Streaming Optimized | `il-so` |
| IT Milano | `italy` |
| IT Streaming Optimized *(geo)* | `italy_2` |
| Iceland | `is` |
| India | `in` |
| Indonesia *(geo)* | `jakarta` |
| Ireland | `ireland` |
| Isle of Man *(geo)* | `man` |
| Israel | `israel` |
| JP Streaming Optimized | `japan_2` |
| JP Tokyo | `japan` |
| KR Streaming Optimized | `kr-so` |
| Kazakhstan | `kazakhstan` |
| LT Streaming Optimized | `lt-so` |
| LU Streaming Optimized | `lu-so` |
| Latvia | `lv` |
| Liechtenstein *(geo)* | `liechtenstein` |
| Lithuania | `lt` |
| Luxembourg | `lu` |
| MX Streaming Optimized | `mx-so` |
| Macao *(geo)* | `macau` |
| Malaysia | `kualalumpur` |
| Malta *(geo)* | `malta` |
| Mexico | `mexico` |
| Moldova | `md` |
| Monaco *(geo)* | `monaco` |
| Mongolia *(geo)* | `mongolia` |
| Montenegro *(geo)* | `montenegro` |
| Morocco *(geo)* | `morocco` |
| NL Netherlands Streaming Optimized | `nl_netherlands-so` |
| NZ Streaming Optimized | `nz-so` |
| Nepal *(geo)* | `np_nepal-pf` |
| Netherlands | `nl_amsterdam` |
| New Zealand | `nz` |
| Nigeria *(geo)* | `nigeria` |
| North Macedonia | `mk` |
| Norway | `no` |
| PL Streaming Optimized | `pl-so` |
| PT Streaming Optimized | `pt-so` |
| Panama | `panama` |
| Peru | `pe_peru-pf` |
| Philippines | `philippines` |
| Poland | `poland` |
| Portugal | `pt` |
| Qatar *(geo)* | `qatar` |
| RO Streaming Optimized | `ro-so` |
| RS Streaming Optimized | `rs-so` |
| Romania | `ro` |
| SE Stockholm | `sweden` |
| SE Streaming Optimized | `sweden_2` |
| SG Streaming Optimized | `sg-so` |
| SK Streaming Optimized | `sk-so` |
| Saudi Arabia *(geo)* | `saudiarabia` |
| Serbia | `rs` |
| Singapore | `sg` |
| Slovakia | `sk` |
| Slovenia | `slovenia` |
| South Africa | `za` |
| South Korea | `kr_south_korea-pf` |
| Sri Lanka *(geo)* | `srilanka` |
| Switzerland | `swiss` |
| TW Streaming Optimized | `tw-so` |
| Taiwan | `taiwan` |
| Turkey *(geo)* | `tr` |
| UK London | `uk` |
| UK Manchester | `uk_manchester` |
| UK Southampton | `uk_southampton` |
| UK Streaming Optimized | `uk_2` |
| Ukraine | `ua` |
| United Arab Emirates | `ae` |
| Uruguay | `uy_uruguay-pf` |
| Venezuela | `venezuela` |
| Vietnam | `vietnam` |
| ZA Streaming Optimized | `za-so` |

</details>

This list comes directly from PIA and is refreshed into the image at build time, so the bundled `data.json` always matches PIA's current servers. To regenerate the readable list yourself:

```bash
curl -s https://serverlist.piaservers.net/vpninfo/servers/v6 | head -1 | \
  jq -r '.regions[] | select(.port_forward) | "\(.name) — \(.id)"' | sort
```

---

## Port Forwarding

**Enabled by default** (`PORT_FORWARDING=true`). On startup a port is requested from PIA, opened in the firewall, and set in qBittorrent automatically.

- Port is assigned randomly by PIA — you cannot specify one
- Port is valid for up to 2 months
- Container refreshes the port binding every 10 minutes to keep it alive
- **If your region doesn't support port forwarding (e.g. all US regions), the container logs a warning and keeps running without it** — it no longer crashes. Pick a [supported region](#pia-regions) to use it.
- If the container restarts too frequently (20+ times in 30 mins) you may hit PIA's rate limit — stop the container and wait 1 hour

---

## Web UI

Access at `http://YOUR_SERVER_IP:8888`

Default username: `admin`
Default password: shown in container logs (`docker logs pia-qbittorrent`)

> Change the password after first login — it changes every restart until you set a permanent one.

---

## Saving .torrent Files

By default, added `.torrent` files are automatically saved to `/downloads/torrents` so you always keep a copy. The folder is created automatically when you add your first torrent.

**Magnet links** are saved too — just a few seconds later. A magnet has no metadata when added, so qBittorrent writes the `.torrent` once it fetches the metadata from the swarm. (If a magnet never finds peers, no file is written — but it wouldn't download anyway.)

> **Existing installs:** this default is only written on a **fresh** config, so if you upgraded from an earlier version it won't appear automatically. To enable it manually, go to **Options → Downloads → Saving Management**, tick **"Copy .torrent files to:"**, enter `/downloads/torrents`, and Save.

---

## auth.conf File

Store credentials securely by mounting an auth file instead of using environment variables:

```
/your/auth.conf:
line 1: your_pia_username
line 2: your_pia_password
```

```bash
docker run ... -v /your/auth.conf:/auth.conf ...
```

When `/auth.conf` is present, `PIA_USERNAME` and `PIA_PASSWORD` are ignored.

---

## Hooks

Create `/config/post-vpn-connect.sh` to run custom code after the VPN connects but before qBittorrent starts.

It runs as `qbtUser`, not as root. `/config` is writable by that user, so anything placed there is only as trustworthy as the user account itself - running it as root would let a compromised qBittorrent escalate to root inside the container. A hook that genuinely needs root must be baked into the image at `/app/post-vpn-connect.sh`, which the container user cannot write.

Available variables:

| Variable | Description |
|----------|-------------|
| `PF_PORT` | The PIA forwarded port (empty if port forwarding is off or unsupported) |
| `WEBUI_PORT` | The Web UI port |
| `VPN_DEVICE` | The VPN interface name (`pia` or `tun0`) |
| `PIA_REGION` | The region as you configured it |
| `VPN_CLIENT` | `wireguard` or `openvpn` |
| `PUID` | The user ID qBittorrent runs as |
| `PGID` | The group ID qBittorrent runs as |

Example:
```bash
MY_IP=$(wget -qO- ifconfig.me/ip)
printf " My external IP is $MY_IP\n"
printf " My forwarding port is $PF_PORT\n"
```

---

## DNS Servers

| Server | Provider |
|--------|----------|
| `9.9.9.9`, `149.112.112.112` | Quad9 |
| `1.1.1.1`, `1.0.0.1` | Cloudflare |
| `8.8.8.8`, `8.8.4.4` | Google |
| `84.200.69.80`, `84.200.70.40` | DNS.WATCH |

Once connected to PIA you can also use PIA's own private DNS. These are reachable
**only through the tunnel**, so they cannot be used before the VPN is up:

| Server | Provides |
|--------|----------|
| `10.0.0.242` | DNS |
| `10.0.0.243` | DNS + Streaming |
| `10.0.0.244` | DNS + MACE (blocks ads and trackers) |
| `10.0.0.241` | DNS + Streaming + MACE |

---

## Build from Source

```bash
git clone https://github.com/GeorgeAL78/pia-qbittorrent-docker.git
cd pia-qbittorrent-docker
docker build -t gjergjk/pia-qbittorrent .
```

---

## Known Issues

- **Banned client error on some trackers**
  - Some private trackers may not have whitelisted the current qBittorrent version yet
  - Check the tracker's forum for supported client versions

- **Port forwarding rate limit**
  - If the container restarts more than 20 times in 30 minutes, PIA will rate limit port forwarding requests
  - **Fix**: Stop the container and wait 1 hour

- **Special characters in password**
  - If your password contains special characters use the `/auth.conf` file instead of environment variables

- **Unauthorized when using proxy for WebUI**
  - **Fix**: Set `CSRFPROTECTION=false`

- **Cannot block IPv6: ip6tables is unavailable**
  - The kill switch blocks IPv6 with `ip6tables`. On a host that has no IPv6 support in its kernel or iptables build, the container refuses to start rather than run with IPv6 unprotected
  - The container cannot fall back to `sysctl` at runtime: Docker mounts `/proc/sys` read-only, so the write silently has no effect
  - **Fix**: set them when *creating* the container - `--sysctl net.ipv6.conf.all.disable_ipv6=1 --sysctl net.ipv6.conf.default.disable_ipv6=1`, or the equivalent commented-out `sysctls:` block in `docker-compose.yml`

- **nft: Protocol not supported**
  - Occurs on older kernels or Synology NAS
  - **Fix**: Set `LEGACY_IPTABLES=true`

- **Files moved to .trash instead of deleted**
  - qBittorrent 5.x defaults to moving files to trash
  - **Fix**: Tools → Options → Advanced → set "Torrent content removing mode" to "Delete files permanently"

---

## Exit Codes

The container exits with these codes. Codes **5** and **7** expect a restart policy
(`--restart unless-stopped`); without one the container stays stopped. Existing
containers can be updated in place with `docker update --restart unless-stopped <name>`.

| Code | Meaning | Needs a restart policy |
|------|---------|------------------------|
| `0` | Normal shutdown | - |
| `1` | Invalid configuration (bad `WEBUI_PORT`, unresolvable `PIA_REGION`, IPv6 cannot be blocked) | No - fix the setting |
| `3` | PIA credentials missing or rejected while fetching a token | No - fix `/auth.conf` |
| `5` | Deliberate restart to recover something that cannot be fixed in place: an expired PIA token (after 6 failed in-place reconnects), or a changed forwarded port that a running qBittorrent cannot be moved to | **Yes** |
| `6` | OpenVPN reported a fatal error in its log | No |
| `7` | VPN authentication failed | No - check credentials |

Before exiting with `5` the container stops qBittorrent gracefully so resume data is
saved and torrents do not re-check on the next start.

---

## Changelog

See [Docker Hub](https://hub.docker.com/r/gjergjk/pia-qbittorrent) for full changelog.

---

## License

[GNU General Public License v3.0](LICENSE)

This project is a fork of [j4ym0/pia-qbittorrent-docker](https://github.com/j4ym0/pia-qbittorrent-docker), originally MIT licensed. The original MIT notice is preserved in the [NOTICE](NOTICE) file.

---

## Disclaimer

This is an unofficial, community-maintained project. It is **not affiliated with, endorsed by, or sponsored by** Private Internet Access or qBittorrent. "Private Internet Access", "PIA", and "qBittorrent" are trademarks of their respective owners and are used here only to describe compatibility.
