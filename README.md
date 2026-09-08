<div align="center">

<img src="readme/icon.png" width="120" alt="pia-qbittorrent logo">

## qBittorrent & Private Internet Access VPN Docker

[![CI](https://img.shields.io/github/actions/workflow/status/GeorgeAL78/pia-qbittorrent-docker/docker-publish.yml?label=CI&logo=github)](https://github.com/GeorgeAL78/pia-qbittorrent-docker/actions)
[![License](https://img.shields.io/github/license/GeorgeAL78/pia-qbittorrent-docker)](LICENSE)
[![qBittorrent](https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fraw.githubusercontent.com%2FGeorgeAL78%2Fpia-qbittorrent-docker%2Fmaster%2FDockerfile&search=release-%28%5Cd%2B%5C.%5Cd%2B%5C.%5Cd%2B%29&replace=%241&label=qBittorrent&color=2186c4&logo=qbittorrent)](https://github.com/qbittorrent/qBittorrent/releases)
[![Unraid CA](https://img.shields.io/badge/Unraid-Community%20Apps-orange)](https://ca.unraid.net/apps?q=pia-qbittorrent)

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

- **Your real IP stays hidden** - if the VPN drops, the container loses its internet instead of quietly falling back to your normal connection
- **It fixes itself** - it notices when the VPN has stopped working - including when it still looks connected - and repairs it without you doing anything
- **A dead VPN server is not your problem** - it moves to another server nearby, and your forwarded port moves with it
- **It keeps up with PIA** - the list of PIA servers is refreshed every time the container starts, so it still works when PIA moves a region onto new machines
- **Faster seeding** - PIA port forwarding is set up for you, wherever your region supports it
- **Downloads survive updates** - it saves your progress on shutdown, so nothing re-checks after a restart
- **Files land with the right owner** - so they are readable on Unraid and other NAS systems without fixing permissions afterwards
- **Your PIA login can stay out of the container settings** - keep it in a protected file instead
- **Runs on a Raspberry Pi** - as well as a normal PC or server

<details>
<summary><b>Technical details</b></summary>

- WireGuard and OpenVPN support
- PIA port forwarding for seeding
- PIA server list refreshed at every container start, falling back to the bundled copy if PIA is unreachable
- Kill switch — all IPv4 and IPv6 traffic blocked if the VPN drops
- Docker healthcheck catches a tunnel that is up but dead, not just a missing interface — it reports `unhealthy` rather than looking fine while torrents hang
- Auto-healing VPN — detects a dead/dropped tunnel and reconnects in place (WireGuard re-registers its key, OpenVPN restarts the client and re-authenticates), escalating to a full container restart if the in-place reconnect can't recover it
- qBittorrent is relaunched after a successful reconnect, so it binds the new tunnel address. Resume data is saved first
- Automatic server failover — if the VPN server you're on goes down, reconnect tries the other servers in your region instead of retrying a dead one, and port forwarding follows it to the new server rather than silently pointing at the old one
- Multi-arch images — `amd64` and `arm64`
- VPN network interface auto-detected and locked (WireGuard `pia` / OpenVPN `tun0`)
- Configurable UID/GID for correct file ownership on Unraid and NAS systems
- Configurable UMASK; download folder permissions preserved across restarts
- Automatic `.torrent` file export to `/downloads/torrents`
- Graceful shutdown — saves resume data so torrents resume instead of re-checking after an update
- Secure credential storage via `auth.conf`
- DNS leak protection with custom DNS servers
- Hook script support after the VPN connects — `/config/post-vpn-connect.sh` runs as the container user; bake a hook into the image at `/app/post-vpn-connect.sh` if it genuinely needs root
- Web UI accessible on your local network

</details>

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

> **Requires an active PIA subscription.** [Get one here](https://www.privateinternetaccess.com/pages/buy-a-vpn/1218buyavpn?conversionpoint=RaFInv_30d&invite=U2FsdGVkX18J1Nv81yTCd-NGcpwQ2M61ZrdiLLbhR3g%2C1nufXzgd9Qroyu8zAyDLK2baD5w) — that is a referral link, which supports this project at no extra cost to you.

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
| `VPN_LOG_DIR` | `/logs` | Where the VPN client writes its log. Must be root-owned — a path under `/config`, or any world-writable directory, is ignored with a warning and `/logs` used instead |
| `TZ` | | Timezone e.g. `America/New_York` |
| `HOSTHEADERVALIDATION` | | Set to `false` if having trouble accessing the WebUI. Has no practical effect unless you also set `WebUI\ServerDomains` to your own hostname — CSRF protection is what guards the Web UI |
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

> ℹ️ **135 of 190 regions support port forwarding; no US region does.** The table below says which. Ignore the `-pf` in a region id — 32 ids end in `-pf` without supporting it.

### All PIA regions

<details>
<summary><h3>🌍 &nbsp;Click to view all 190 PIA regions</h3></summary>

| Location | `PIA_REGION` | Port forwarding |
|----------|--------------|-----------------|
| AR Streaming Optimized | `ar-so` | Yes |
| AT Streaming Optimized | `at-so` | Yes |
| AU Adelaide | `au_adelaide-pf` | Yes |
| AU Brisbane | `au_brisbane-pf` | Yes |
| AU Melbourne | `aus_melbourne` | Yes |
| AU Perth | `aus_perth` | Yes |
| AU Sydney | `aus` | Yes |
| Albania | `al` | Yes |
| Algeria *(geo)* | `dz` | Yes |
| Andorra *(geo)* | `ad` | Yes |
| Argentina | `ar` | Yes |
| Armenia *(geo)* | `yerevan` | Yes |
| Australia Streaming Optimized | `au_australia-so` | Yes |
| Austria | `austria` | Yes |
| BE Streaming Optimized | `be-so` | Yes |
| BR Streaming Optimized | `br-so` | Yes |
| Bahamas | `bahamas` | Yes |
| Bangladesh *(geo)* | `bangladesh` | Yes |
| Belgium | `belgium` | Yes |
| Bolivia | `bo_bolivia-pf` | Yes |
| Bosnia and Herzegovina *(geo)* | `ba` | Yes |
| Brazil | `br` | Yes |
| Bulgaria | `sofia` | Yes |
| CA Montreal | `ca` | Yes |
| CA Ontario | `ca_ontario` | Yes |
| CA Ontario Streaming Optimized | `ca_ontario-so` | Yes |
| CA Toronto | `ca_toronto` | Yes |
| CA Vancouver | `ca_vancouver` | Yes |
| CH Streaming Optimized | `ch-so` | Yes |
| CL Streaming Optimized | `cl-so` | Yes |
| Cambodia *(geo)* | `cambodia` | Yes |
| Chile | `santiago` | Yes |
| China *(geo)* | `china` | Yes |
| Colombia | `bogota` | Yes |
| Costa Rica | `sanjose` | Yes |
| Croatia | `zagreb` | Yes |
| Cyprus *(geo)* | `cyprus` | Yes |
| Czech Republic | `czech` | Yes |
| DE Berlin | `de_berlin` | Yes |
| DE Frankfurt | `de-frankfurt` | Yes |
| DE Germany Streaming Optimized | `de_germany-so` | Yes |
| DK Streaming Optimized | `denmark_2` | Yes |
| Denmark | `denmark` | Yes |
| ES Madrid | `spain` | Yes |
| ES Streaming Optimized | `es-so` | Yes |
| ES Valencia | `es-valencia` | Yes |
| Ecuador | `ec_ecuador-pf` | Yes |
| Egypt *(geo)* | `egypt` | Yes |
| Estonia | `ee` | Yes |
| FI Helsinki | `fi` | Yes |
| FI Streaming Optimized | `fi_2` | Yes |
| FR Streaming Optimized | `fr-so` | Yes |
| France | `france` | Yes |
| Georgia *(geo)* | `georgia` | Yes |
| Greece | `gr` | Yes |
| Greenland | `greenland` | Yes |
| Guatemala | `gt_guatemala-pf` | Yes |
| HU Streaming Optimized | `hu-so` | Yes |
| Hong Kong *(geo)* | `hk` | Yes |
| Hungary | `hungary` | Yes |
| IL Israel 2 | `il_israel_2-pf` | Yes |
| IL Streaming Optimized | `il-so` | Yes |
| IT Milano | `italy` | Yes |
| IT Streaming Optimized *(geo)* | `italy_2` | Yes |
| Iceland | `is` | Yes |
| India | `in` | Yes |
| Indonesia *(geo)* | `jakarta` | Yes |
| Ireland | `ireland` | Yes |
| Isle of Man *(geo)* | `man` | Yes |
| Israel | `israel` | Yes |
| JP Streaming Optimized | `japan_2` | Yes |
| JP Tokyo | `japan` | Yes |
| KR Streaming Optimized | `kr-so` | Yes |
| Kazakhstan | `kazakhstan` | Yes |
| LT Streaming Optimized | `lt-so` | Yes |
| LU Streaming Optimized | `lu-so` | Yes |
| Latvia | `lv` | Yes |
| Liechtenstein *(geo)* | `liechtenstein` | Yes |
| Lithuania | `lt` | Yes |
| Luxembourg | `lu` | Yes |
| MX Streaming Optimized | `mx-so` | Yes |
| Macao *(geo)* | `macau` | Yes |
| Malaysia | `kualalumpur` | Yes |
| Malta *(geo)* | `malta` | Yes |
| Mexico | `mexico` | Yes |
| Moldova | `md` | Yes |
| Monaco *(geo)* | `monaco` | Yes |
| Mongolia *(geo)* | `mongolia` | Yes |
| Montenegro *(geo)* | `montenegro` | Yes |
| Morocco *(geo)* | `morocco` | Yes |
| NL Netherlands Streaming Optimized | `nl_netherlands-so` | Yes |
| NZ Streaming Optimized | `nz-so` | Yes |
| Nepal *(geo)* | `np_nepal-pf` | Yes |
| Netherlands | `nl_amsterdam` | Yes |
| New Zealand | `nz` | Yes |
| Nigeria *(geo)* | `nigeria` | Yes |
| North Macedonia | `mk` | Yes |
| Norway | `no` | Yes |
| PL Streaming Optimized | `pl-so` | Yes |
| PT Streaming Optimized | `pt-so` | Yes |
| Panama | `panama` | Yes |
| Peru | `pe_peru-pf` | Yes |
| Philippines | `philippines` | Yes |
| Poland | `poland` | Yes |
| Portugal | `pt` | Yes |
| Qatar *(geo)* | `qatar` | Yes |
| RO Streaming Optimized | `ro-so` | Yes |
| RS Streaming Optimized | `rs-so` | Yes |
| Romania | `ro` | Yes |
| SE Stockholm | `sweden` | Yes |
| SE Streaming Optimized | `sweden_2` | Yes |
| SG Streaming Optimized | `sg-so` | Yes |
| SK Streaming Optimized | `sk-so` | Yes |
| Saudi Arabia *(geo)* | `saudiarabia` | Yes |
| Serbia | `rs` | Yes |
| Singapore | `sg` | Yes |
| Slovakia | `sk` | Yes |
| Slovenia | `slovenia` | Yes |
| South Africa | `za` | Yes |
| South Korea | `kr_south_korea-pf` | Yes |
| Sri Lanka *(geo)* | `srilanka` | Yes |
| Switzerland | `swiss` | Yes |
| TW Streaming Optimized | `tw-so` | Yes |
| Taiwan | `taiwan` | Yes |
| Turkey *(geo)* | `tr` | Yes |
| UK London | `uk` | Yes |
| UK Manchester | `uk_manchester` | Yes |
| UK Southampton | `uk_southampton` | Yes |
| UK Streaming Optimized | `uk_2` | Yes |
| US Alabama *(geo)* | `us_alabama-pf` | No |
| US Alaska *(geo)* | `us_alaska-pf` | No |
| US Arkansas *(geo)* | `us_arkansas-pf` | No |
| US Atlanta | `us_atlanta` | No |
| US Baltimore *(geo)* | `us-baltimore` | No |
| US California | `us_california` | No |
| US Chicago | `us_chicago` | No |
| US Connecticut *(geo)* | `us_connecticut-pf` | No |
| US Denver | `us_denver` | No |
| US East | `us-newjersey` | No |
| US East Streaming Optimized | `us-streaming` | No |
| US Florida | `us_florida` | No |
| US Honolulu *(geo)* | `us-honolulu` | No |
| US Houston | `us_houston` | No |
| US Idaho *(geo)* | `us_idaho-pf` | No |
| US Indiana *(geo)* | `us-indiana` | No |
| US Iowa *(geo)* | `us_iowa-pf` | No |
| US Kansas *(geo)* | `us_kansas-pf` | No |
| US Kentucky *(geo)* | `us-kentucky` | No |
| US Las Vegas | `us_las_vegas` | No |
| US Louisiana *(geo)* | `us_louisiana-pf` | No |
| US Maine *(geo)* | `us_maine-pf` | No |
| US Massachusetts | `us_massachusetts-pf` | No |
| US Michigan *(geo)* | `us_michigan-pf` | No |
| US Minnesota *(geo)* | `us_minnesota-pf` | No |
| US Mississippi *(geo)* | `us_mississippi-pf` | No |
| US Missouri *(geo)* | `us_missouri-pf` | No |
| US Montana *(geo)* | `us_montana-pf` | No |
| US Nebraska *(geo)* | `us_nebraska-pf` | No |
| US New Hampshire *(geo)* | `us_new_hampshire-pf` | No |
| US New Mexico | `us_new_mexico-pf` | No |
| US New York | `us_new_york_city` | No |
| US North Carolina *(geo)* | `us_north_carolina-pf` | No |
| US North Dakota *(geo)* | `us_north_dakota-pf` | No |
| US Ohio *(geo)* | `us_ohio-pf` | No |
| US Oklahoma *(geo)* | `us_oklahoma-pf` | No |
| US Oregon *(geo)* | `us_oregon-pf` | No |
| US Pennsylvania *(geo)* | `us_pennsylvania-pf` | No |
| US Rhode Island *(geo)* | `us_rhode_island-pf` | No |
| US Salt Lake City | `us-salt-lake-city` | No |
| US Seattle | `us_seattle` | No |
| US Silicon Valley | `us_silicon_valley` | No |
| US South Carolina *(geo)* | `us_south_carolina-pf` | No |
| US South Dakota | `us_south_dakota-pf` | No |
| US Tennessee *(geo)* | `us-tennessee` | No |
| US Texas | `us_south_west` | No |
| US Vermont *(geo)* | `us_vermont-pf` | No |
| US Virginia *(geo)* | `us_virginia-pf` | No |
| US Washington DC | `us_washington_dc` | No |
| US West | `us3` | No |
| US West Streaming Optimized | `us-streaming-2` | No |
| US West Virginia *(geo)* | `us_west_virginia-pf` | No |
| US Wilmington *(geo)* | `us-wilmington` | No |
| US Wisconsin *(geo)* | `us_wisconsin-pf` | No |
| US Wyoming | `us_wyoming-pf` | No |
| Ukraine | `ua` | Yes |
| United Arab Emirates | `ae` | Yes |
| Uruguay | `uy_uruguay-pf` | Yes |
| Venezuela | `venezuela` | Yes |
| Vietnam *(geo)* | `vietnam` | Yes |
| ZA Streaming Optimized | `za-so` | Yes |

</details>

The container refreshes this list from PIA on every start, so it is never limited to the table below. To regenerate the table yourself:

```bash
curl -s https://serverlist.piaservers.net/vpninfo/servers/v6 | head -1 | \
  jq -r '.regions[] | "\(.name) — \(.id) — pf=\(.port_forward)"' | sort
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

It runs as `qbtUser`, not root. A hook that needs root must be baked into the image at `/app/post-vpn-connect.sh`, which the container user cannot write.

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

## Reading the startup log

The first line reports whether the PIA server list could be refreshed:

| Line | Meaning |
|------|---------|
| `DOWNLOADED 190 regions from PIA` | Got PIA's current list |
| `PIA UNREACHABLE - using the 190 regions baked into this image` | Using the bundled copy |
| `FAILED to write the file - using the 190 regions baked into this image` | Using the bundled copy |

All three are normal — the container works either way.

---

## Known Issues

- **Downloads stopped after the VPN reconnected** *(fixed in 5.2.3-19)*
  - Affected anyone who had saved preferences in the Web UI, which records the tunnel address at that moment instead of following the interface. After a reconnect or server failover the address changes, and qBittorrent kept binding the old one
  - The tunnel stays healthy and nothing in the Web UI indicates a problem; transfers simply stop. `qbittorrent.log` shows `Failed to listen on IP ... Address not available`
  - **Fix**: update to 5.2.3-19 or later. On an older version, `docker restart <container>` restores it immediately

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
