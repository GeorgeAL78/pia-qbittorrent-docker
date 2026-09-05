#!/bin/sh

# UID and GID are read-only shell built-ins in ash/bash (always 0 when running
# as root). Capture the user-supplied values from the environment NOW, before
# the shell's built-ins shadow them, so the later /etc/passwd patching works.
PUID=$(printenv UID)
PGID=$(printenv GID)

exitOnError(){
  # $1 must be set to $?
  status=$1
  message=$2
  [ "$message" != "" ] || message="Undefined error"
  if [ $status != 0 ]; then
    printf "\n"
    printf "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $message, with status $status\n"
    case "$message" in
      *"Could not fetch rule set generation id: Permission denied (you must be root)"*)
          printf "Check you have added --cap-add=NET_ADMIN when creating your container\n"
          ;;
      *)
          printf "\n"
           ;;
    esac
    exit $status
  fi
}

exitIfUnset(){
  # $1 is the name of the variable to check - not the variable itself
  var="$(eval echo "\$$1")"
  if [ -z "$var" ]; then
    printf "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] Environment variable $1 is not set\n"
    exit 1
  fi
}

exitIfNotIn(){
  # $1 is the name of the variable to check - not the variable itself
  # $2 is a string of comma separated possible values
  var="$(eval echo "\$$1")"
  for value in $(echo $2 | sed "s/,/ /g")
  do
    if [ "$var" = "$value" ]; then
      return 0
    fi
  done
  printf "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] Environment variable $1 cannot be '$var' and must be one of the following: "
  for value in $(echo $2 | sed "s/,/ /g")
  do
    printf "$value "
  done
  printf "\n"
  exit 1
}

is_enabled() {
  # $1 is the value to check if it is enabled
  local value=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  echo "$value" | grep -q -E '^(true|yes|1|on|enabled)$'
}


# Define paths for iptables versions
IPTABLES_LEGACY="/usr/sbin/iptables-legacy"
IP6TABLES_LEGACY="/usr/sbin/ip6tables-legacy"
IPTABLES_NFT="/usr/sbin/iptables-nft"
IP6TABLES_NFT="/usr/sbin/ip6tables-nft"
IPTABLES_LEGACY_ALPINE="/usr/sbin/xtables-legacy-multi"
IPTABLES_NFT_ALPINE="/usr/sbin/xtables-nft-multi"

# link the lib for qbittorrent for alpine
export LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64:${LD_LIBRARY_PATH}

# get correct iptables for version
IPTABLE_VERSION=$(iptables --version 2>/dev/null | head -n1 | cut -d' ' -f2)
if [ "$LEGACY_IPTABLES"  = "true" ]; then 
  if [ "$(grep ^NAME= /etc/os-release | cut -d '=' -f 2 | tr -d '"')" = "Alpine Linux" ]; then 
    IPTABLE_VERSION=$("$IPTABLES_LEGACY_ALPINE" iptables --version 2>/dev/null | head -n1 | cut -d' ' -f2)
  else
    IPTABLE_VERSION=$("$IPTABLES_LEGACY" --version 2>/dev/null | head -n1 | cut -d' ' -f2)
  fi
else
  if [ "$(grep ^NAME= /etc/os-release | cut -d '=' -f 2 | tr -d '"')" = "Alpine Linux" ]; then 
    IPTABLE_VERSION=$("$IPTABLES_NFT_ALPINE" iptables --version 2>/dev/null | head -n1 | cut -d' ' -f2)
  else
    IPTABLE_VERSION=$("$IPTABLES_NFT" --version 2>/dev/null | head -n1 | cut -d' ' -f2)
  fi
fi

printf " =========================================\n"
printf " ============== qBittorrent ==============\n"
printf " =================== + ===================\n"
printf " ============= PIA CONTAINER =============\n"
printf " =========================================\n"
printf " OS: $(grep PRETTY_NAME= /etc/os-release | cut -d "\"" -f 2 | cut -d "\"" -f 1)\n"
printf " =========================================\n"
printf " OpenVPN version: $(openvpn --version | head -n 1 | grep -E "OpenVPN [0-9.]* " | cut -d" " -f2)\n"
printf " Wireguard version: $(wg --version | head -n 1 | grep -E " v[0-9.]* " | cut -d" " -f2)\n"
printf " Iptables version: $IPTABLE_VERSION\n"
printf " Container version: ${CONTAINER_VERSION:-unknown}\n"
printf " qBittorrent version: $(qbittorrent-nox --version | cut -d" " -f2)\n"
printf " =========================================\n"
printf "\n"

############################################
# Check Depreciated Parameters
############################################
if [ -n "$USER" ] && [ -z "$PIA_USERNAME" ]; then
  printf "[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] The use of environment variable USER is depreciated.\n"
  printf " Please use PIA_USERNAME\n"
  printf " or use a secure auth.conf file instead. See the wiki for more information:\n"
  printf " https://github.com/GeorgeAL78/pia-qbittorrent-docker#authconf-file\n"
  printf "\n"
  export PIA_USERNAME=$USER
  unset -v USER
fi
if [ -n "$USERNAME" ] && [ -z "$PIA_USERNAME" ]; then
  printf "[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] The use of environment variable USERNAME is depreciated.\n"
  printf " Please use PIA_USERNAME\n"
  printf " or use a secure auth.conf file instead. See the wiki for more information:\n"
  printf " https://github.com/GeorgeAL78/pia-qbittorrent-docker#authconf-file\n"
  printf "\n"
  export PIA_USERNAME=$USERNAME
  unset -v USERNAME
fi
if [ -n "$PASSWORD" ] && [ -z "$PIA_PASSWORD" ]; then
  printf "[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] The use of environment variable PASSWORD is depreciated.\n"
  printf " Please use PIA_PASSWORD\n"
  printf " or use a secure auth.conf file instead. See the wiki for more information:\n"
  printf " https://github.com/GeorgeAL78/pia-qbittorrent-docker#authconf-file\n"
  printf "\n"
  export PIA_PASSWORD=$PASSWORD
  unset -v PASSWORD
fi
if [ -n "$REGION" ]; then
  printf "[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] The use of environment variable REGION is depreciated.\n"
  printf " Please use PIA_REGION\n"
  printf "\n"
  export PIA_REGION=$REGION
  unset -v REGION
fi

# convert vpn to lower case for dir
server=$(echo "$PIA_REGION" | tr '[:upper:]' '[:lower:]')

# Resolve PIA_REGION to exactly one region, preferring an exact id match, then an
# exact name match, and only then a substring match. The old lookup was substring-
# only, so short ids silently landed on the wrong place: "no" matched IT Milano
# rather than Norway, and "in" matched NL Netherlands rather than India.
region_match=$(jq -r --arg SERVER "$server" '
  def normalize: gsub("[_-]"; " ") | ascii_downcase | gsub("\\s+"; " ");
  ($SERVER | ascii_downcase) as $raw |
  ($SERVER | normalize) as $search |
  [.regions[] | select((.id | ascii_downcase) == $raw)] as $exact_id |
  [.regions[] | select((.name | normalize) == $search)] as $exact_name |
  [.regions[] | select((.name | normalize | contains($search)) or (.id | normalize | contains($search)))] as $fuzzy |
  (if ($exact_id | length) > 0 then {how:"exact", r:$exact_id[0], n:1}
   elif ($exact_name | length) > 0 then {how:"exact", r:$exact_name[0], n:1}
   elif ($fuzzy | length) > 0 then {how:"fuzzy", r:$fuzzy[0], n:($fuzzy|length)}
   else {how:"none", r:null, n:0} end)
  | if .r then "\(.how)|\(.r.id)|\(.r.name)|\(.n)" else "none|||0" end
' /app/data.json 2>/dev/null)

region_how=$(printf "%s" "$region_match" | cut -d"|" -f1)
region_id=$(printf "%s" "$region_match" | cut -d"|" -f2)
region_name=$(printf "%s" "$region_match" | cut -d"|" -f3)
region_n=$(printf "%s" "$region_match" | cut -d"|" -f4)

# PIA names the OpenVPN profiles after the region NAME (lowercased, spaces to
# underscores) - not after the id - so derive it that way rather than trusting the
# raw input. Falls back to the raw input if the derived profile is missing.
ovpn_profile="$server"
if [ -n "$region_name" ]; then
  derived=$(printf "%s" "$region_name" | tr "[:upper:]" "[:lower:]" | tr " " "_")
  if [ -f "/openvpn/nextgen/$derived.ovpn" ]; then
    ovpn_profile="$derived"
  fi
fi

if [ "$region_how" = "fuzzy" ] && [ "$region_n" -gt 1 ]; then
  printf "[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] PIA_REGION '$PIA_REGION' is ambiguous ($region_n regions match) - using '$region_name'. Use an exact region id to be certain.\n"
fi

############################################
# CHECK if VPN_CLIENT should be openvpn or wireguard
############################################
if [ -z $VPN_CLIENT ]; then
  printf "Defaulting to OpenVPN\n"
  VPN_CLIENT="openvpn"
fi
if [ "$VPN_CLIENT" != "openvpn" ] && [ "$VPN_CLIENT" != "wireguard" ]; then
  VPN_CLIENT="openvpn"
fi

############################################
# CHECK PARAMETERS
############################################
if [ "$VPN_CLIENT" = "openvpn" ]; then
  if [ ! -f "/openvpn/nextgen/$ovpn_profile.ovpn" ]; then
    printf "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] No OpenVPN profile for PIA_REGION '$PIA_REGION'.\n"
    if [ -n "$region_name" ]; then
      printf "          Matched region '$region_name' but /openvpn/nextgen/$ovpn_profile.ovpn does not exist.\n"
      printf "          This region may be WireGuard-only - try VPN_CLIENT=wireguard, or pick another region.\n"
    else
      printf "          That region was not found in the PIA server list.\n"
    fi
    exit 1
  fi
fi
if [ -z $WEBUI_PORT ]; then
  WEBUI_PORT=8888
fi
# Validate WEBUI_PORT. The previous check was:
#   if [ `echo $WEBUI_PORT | ack "^[0-9]+$"` != $WEBUI_PORT ]
# which did the OPPOSITE of its job for non-numeric input: ack printed nothing,
# so the test became [ != abc ], which errors ("unknown operand") and evaluates
# false - so an invalid port was ACCEPTED and passed on to the iptables rules and
# qbittorrent-nox. The numeric comparisons below would then error too. A POSIX
# case avoids the command substitution, the word splitting and the ack dependency.
case "$WEBUI_PORT" in
  *[!0-9]*|"")
    printf "WEBUI_PORT is not a valid number\n"
    exit 1
    ;;
esac
if [ "$WEBUI_PORT" -lt 1024 ]; then
  printf "WEBUI_PORT cannot be a privileged port under port 1024\n"
  exit 1
elif [ "$WEBUI_PORT" -gt 65535 ]; then
  printf "WEBUI_PORT cannot be a port higher than the maximum port 65535\n"
  exit 1
fi
if [ -z $VPN_LOG_DIR ]; then
  VPN_LOG_DIR=/logs
fi

############################################
# SHOW PARAMETERS
############################################
printf "System parameters:\n"
printf " * userID: $PUID\n"
printf " * groupID: $PGID\n"
printf " * timezone: $(date +"%Z %z")\n"
printf "VPN parameters:\n"
printf " * Region: $server\n"
printf " * VPN Client: $VPN_CLIENT\n"
printf "Local network parameters:\n"
printf " * Web UI port: $WEBUI_PORT\n"
printf " * Adding PIA DNS Servers\n"
cat /dev/null > /etc/resolv.conf
for name_server in $(echo $DNS_SERVERS | sed "s/,/ /g")
do
	echo " * * Adding $name_server to resolv.conf"
	echo "nameserver $name_server" >> /etc/resolv.conf
done

############################################
# Change Timezone
############################################
if [ -n "$TZ" ]; then
  printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Writing Timezone info $TZ\n"
  
  # Check if the timezone data exists
  if [ ! -f "/usr/share/zoneinfo/$TZ" ]; then
    printf "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] Timezone '$TZ' not found. Check the timezone\n"
  else
    if [ -f /etc/localtime ]; then
      printf "[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] localtime file already exists! Not editing\n"
    else
      ln -sf  "/usr/share/zoneinfo/$TZ" /etc/localtime
      printf " * Updated localtime\n"
    fi
    
    if [ -f /etc/timezone ]; then
      printf "[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] timezone file already exists! Not editing\n"
    else
      echo "$TZ" > /etc/timezone
      printf " * Updated timezone\n"
    fi
  fi
fi

#####################################################
# Writes to protected file and remove PIA_USERNAME, PIA_PASSWORD
# Best option is to mount a secure file using docker
# -v /auth-file.conf:/auth.conf
#####################################################
if [ -f /auth.conf ]; then
  if [ "$(wc -l < /auth.conf)" -gt 0 ] && [ "$(wc -c < /auth.conf)" -gt 10 ]; then
    printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] /auth.conf file looks good\n"
    if [ -n "$PIA_USERNAME" ] || [ -n "$PIA_PASSWORD" ]; then
      printf "  * Using credentials from /auth.conf\n"
      printf "  * Ignoring environment variables PIA_USERNAME and PIA_PASSWORD\n"
      printf "[Warning] Please remove PIA_USERNAME and PIA_PASSWORD environment variables\n"
    fi
  else
    printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Please check /auth.conf file. Check line 1 is your username and line 2 is your password\n"
    exit 7
  fi
else
  # No auth file mounted creating it from environment variables
  printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Unable to find /auth.conf file, creating it from environment variables\n"
  exitIfUnset PIA_USERNAME
  exitIfUnset PIA_PASSWORD
  printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Writing PIA_USERNAME and PIA_PASSWORD to protected file /auth.conf..."
  echo "$PIA_USERNAME" > /auth.conf
  exitOnError $?
  echo "$PIA_PASSWORD" >> /auth.conf
  exitOnError $?
  chmod 400 /auth.conf
  exitOnError $?
  printf "DONE\n"
fi
# Check if user vars have been set and clear them
if [ -n "$PIA_USERNAME" ] || [ -n "$PIA_PASSWORD" ]; then
  printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Clearing environment variables PIA_USERNAME and PIA_PASSWORD..."
  unset -v PIA_USERNAME
  unset -v PIA_PASSWORD
  printf "DONE\n"
fi

############################################
#            VPN configuration
############################################
if [ "$VPN_CLIENT" = "wireguard" ]; then
  printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Configuring WireGuard VPN client...\n"

if [ -f /proc/net/if_inet6 ] && ( [ $(sysctl -n net.ipv6.conf.all.disable_ipv6) -ne 1 ] || [ $(sysctl -n net.ipv6.conf.default.disable_ipv6) -ne 1 ] ); then
    printf " * Disabling ipv6 as not supported\n"
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1 || true
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1 || true
  fi

  pia_gen=$(curl -s --connect-timeout 8 --max-time 20 -u "$(sed '1!d' /auth.conf):$(sed '2!d' /auth.conf)" \
    "https://privateinternetaccess.com/gtoken/generateToken")

  if [ "$(echo "$pia_gen" | jq -r '.status')" != "OK" ]; then
    printf " [$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] getting token\n"
    printf " =========================================\n"
    printf " =======Check username and password=======\n"
    printf " =========================================\n"
    exit 3
  fi

  piatoken=$(echo "$pia_gen" | jq -r '.token')
  if [ ! -z $piatoken ]; then
    printf " * Got PIA token\n"
  fi

  privateKey="$(wg genkey)"
  if [ ! -z $privateKey ]; then
    printf " * Got private key\n"
  fi

  publicKey="$( echo "$privateKey" | wg pubkey)"
  if [ ! -z $publicKey ]; then
    printf " * Got Public key\n"
  fi

  # Use the region resolved earlier (exact id > exact name > substring) rather than
  # repeating a substring-only lookup here, so both VPN clients agree on the region.
  if regiondata=$(jq -e --arg RID "$region_id" '.regions[] | select(.id == $RID)' /app/data.json); then
    
    printf " * Got PIA region data\n"
    
    # Extract wg_cn and wg_ip from the region data (first server is the default)
    wg_cn=$(echo "$regiondata" | jq -r ".servers.wg | .[0].cn")
    wg_ip=$(echo "$regiondata" | jq -r ".servers.wg | .[0].ip")

    # All servers in this region, as "ip cn" lines - used to fail over to a
    # different server if the default one stops working. Every one of these IPs
    # is added to the kill switch below (VPNIPS), so failover never needs a
    # firewall change at runtime.
    WG_SERVERS=$(echo "$regiondata" | jq -r '.servers.wg[] | "\(.ip) \(.cn)"')
    wg_server_count=$(echo "$WG_SERVERS" | grep -c .)
    if [ "$wg_server_count" -gt 1 ]; then
      printf " * %s servers available in this region (failover enabled)\n" "$wg_server_count"
    fi

    # Get wg_port from groups (this part doesn't depend on region selection)
    wg_port=$(jq -r '.groups.wg | .[0] | .ports | .[0]' /app/data.json)
    
  else
    printf "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] Getting region data, check PIA_REGION\n"
    exit 1
  fi

  WG_IP="$(echo $regiondata | jq -r '.servers.wg[0].ip')"
  WG_HOSTNAME="$(echo $regiondata | jq -r '.servers.wg[0].cn')"

  printf " * Getting wireguard config for $server...\n"
  # Try each server in the region until one registers the key.
  # Two bugs are fixed here. (1) There was NO TIMEOUT on this call, so a server
  # that accepted the connection but never answered hung startup indefinitely -
  # the container just sat at this line forever with no error. (2) Only the
  # first server was ever tried, so a dead one could not be recovered from even
  # when the region had a healthy server; every restart retried the same dead
  # server. Failover already existed for reconnects - startup needs it too, and
  # arguably more, since nothing else runs until this succeeds.
  rm -f /tmp/.wg_start.json /tmp/.wg_start.server
  echo "$WG_SERVERS" | while read -r s_ip s_cn; do
    [ -z "$s_ip" ] && continue
    r="$(curl -s --connect-timeout 8 --max-time 20 -G \
      --connect-to "$s_cn::$s_ip:" \
      --cacert "/app/ca.rsa.4096.crt" \
      --data-urlencode "pt=$piatoken" \
      --data-urlencode "pubkey=$publicKey" \
      "https://$s_cn:$wg_port/addKey")"
    if [ "$(echo "$r" | jq -r '.status' 2>/dev/null)" = "OK" ]; then
      printf '%s\n' "$r" > /tmp/.wg_start.json
      printf '%s %s\n' "$s_ip" "$s_cn" > /tmp/.wg_start.server
      break
    fi
    printf "   * Server $s_ip did not respond - trying next\n"
  done
  if [ -s /tmp/.wg_start.json ]; then
    wireguard_json="$(cat /tmp/.wg_start.json)"
    sel_ip="$(awk '{print $1}' /tmp/.wg_start.server)"
    sel_cn="$(awk '{print $2}' /tmp/.wg_start.server)"
    if [ "$sel_ip" != "$wg_ip" ]; then
      printf "   * Using failover server $sel_ip ($sel_cn)\n"
    fi
    # Point every server var at whichever one accepted us, so the tunnel config,
    # the firewall endpoint and any later refresh all use the same server.
    wg_ip="$sel_ip"
    wg_cn="$sel_cn"
    WG_IP="$sel_ip"
    WG_HOSTNAME="$sel_cn"
  else
    wireguard_json=""
  fi
  rm -f /tmp/.wg_start.json /tmp/.wg_start.server

  if [ "$(echo "$wireguard_json" | jq -r '.status')" != "OK" ]; then
    if [ -z "$wireguard_json" ]; then
      printf "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] No server in region '$server' would register our key (tried all of them). PIA may be having trouble, or try another region.\n"
    else
      printf "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] Getting wireguard Settings - $(echo "$wireguard_json" | jq -r '.status')\n"
    fi
    exit 5
  fi

  printf " * Writing Wireguard connection settings..."
  if [ ! -d /etc/wireguard ]; then
    mkdir /etc/wireguard
  fi

  # Generate PIA WireGuard config
  cat > /etc/wireguard/pia.conf <<EOF
    [Interface]
    PrivateKey = ${privateKey}
    Address = $(echo "$wireguard_json" | jq -r '.peer_ip')
    #DNS = $(echo "$wireguard_json" | jq -r '.dns_servers[0]')
    Table = off

    [Peer]
    PublicKey = $(echo "$wireguard_json" | jq -r '.server_key')
    AllowedIPs = 0.0.0.0/0
    Endpoint = ${WG_IP}:$(echo "$wireguard_json" | jq -r '.server_port')
    PersistentKeepalive = 25
EOF

  # Get VPN Servers for firewall. ALL of the region's servers are allowed (not
  # just the connected one) so reconnect can fail over to another server without
  # modifying the firewall. They all listen on the same port, and each is a PIA
  # server we would legitimately connect to, so this does not widen exposure
  # beyond "this region's PIA servers on the WireGuard port".
  VPNIPS=$(echo "$WG_SERVERS" | awk '{print $1}')
  PORT=$(echo "$wireguard_json" | jq -r '.server_port')
  printf "DONE\n"

else
  printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Configuring OpenVPN VPN client...\n"

  ############################################
  # CHECK FOR TUN DEVICE
  ############################################
  if [ "$(cat /dev/net/tun 2>&1 /dev/null)" != "cat: read error: File descriptor in bad state" ]; then
    printf "[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] TUN device is not available, creating it..."
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200
    exitOnError $?
    # 0600, matching what Docker itself creates with --device. The OpenVPN config
    # carries no user/group directive, so openvpn stays root and opens this fine;
    # 0666 let anything in the container - qBittorrent included - read and write
    # the tunnel device.
    chmod 0600 /dev/net/tun
    printf "DONE\n"
  fi

  ############################################
  # Reading chosen OpenVPN configuration
  ############################################
  printf " * Reading OpenVPN configuration...\n"
  CONNECTIONSTRING=$(grep 'privacy.network' "/openvpn/nextgen/$ovpn_profile.ovpn")
  exitOnError $?
  PORT=$(echo $CONNECTIONSTRING | cut -d' ' -f3)
  if [ "$PORT" = "" ]; then
    printf "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] Port not found for $server\n"
    exit 1
  fi
  PIADOMAIN=$(echo $CONNECTIONSTRING | cut -d' ' -f2)
  if [ "$PIADOMAIN" = "" ]; then
    printf "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] Domain not found for $server\n"
    exit 1
  fi
  printf " * Port: $PORT\n"
  printf " * Domain: $PIADOMAIN\n"
  printf " * Detecting IP addresses corresponding to $PIADOMAIN...\n"
  VPNIPS=$(dig $PIADOMAIN +short | grep '^[.0-9]*$')
  exitOnError $?
  if [ "$VPNIPS" = "" ]; then
    printf "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] Unable to connect to $PIADOMAIN"
    exit 3
  fi
  for ip in $VPNIPS; do
    printf " * * $ip\n";
  done

  ############################################
  # Writing target OpenVPN files
  ############################################
  TARGET_PATH="/openvpn/target"
  printf " * Creating target OpenVPN files in $TARGET_PATH..."
  rm -rf $TARGET_PATH/*
  cd "/openvpn/nextgen"
  cp -f *.crt "$TARGET_PATH"
  exitOnError $? "Cannot copy crt file to $TARGET_PATH"
  cp -f *.pem "$TARGET_PATH"
  exitOnError $? "Cannot copy pem file to $TARGET_PATH"
  cp -f "$ovpn_profile.ovpn" "$TARGET_PATH/config.ovpn"
  exitOnError $? "Cannot copy $server.ovpn file to $TARGET_PATH"
  sed -i "/$CONNECTIONSTRING/d" "$TARGET_PATH/config.ovpn"
  exitOnError $? "Cannot delete '$CONNECTIONSTRING' from $TARGET_PATH/config.ovpn"
  sed -i '/resolv-retry/d' "$TARGET_PATH/config.ovpn"
  exitOnError $? "Cannot delete 'resolv-retry' from $TARGET_PATH/config.ovpn"
  for ip in $VPNIPS; do
    echo "remote $ip $PORT" >> "$TARGET_PATH/config.ovpn"
    exitOnError $? "Cannot add 'remote $ip $PORT' to $TARGET_PATH/config.ovpn"
  done
  # Uses the username/password from this file to get the token from PIA
  echo "auth-user-pass /auth.conf" >> "$TARGET_PATH/config.ovpn"
  exitOnError $? "Cannot add 'auth-user-pass /auth.conf' to $TARGET_PATH/config.ovpn"
  # Reconnects automatically on failure
  echo "auth-retry nointeract" >> "$TARGET_PATH/config.ovpn"
  exitOnError $? "Cannot add 'auth-retry nointeract' to $TARGET_PATH/config.ovpn"
  # Prevents auth_failed infinite loops - make it interact? Remove persist-tun? nobind?
  echo "pull-filter ignore \"auth-token\"" >> "$TARGET_PATH/config.ovpn"
  exitOnError $? "Cannot add 'pull-filter ignore \"auth-token\"' to $TARGET_PATH/config.ovpn"
  echo "mssfix 1300" >> "$TARGET_PATH/config.ovpn"
  exitOnError $? "Cannot add 'mssfix 1300' to $TARGET_PATH/config.ovpn"
  echo "script-security 2" >> "$TARGET_PATH/config.ovpn"
  exitOnError $? "Cannot add 'script-security 2' to $TARGET_PATH/config.ovpn"
  #echo "up /etc/openvpn/update-resolv-conf" >> "$TARGET_PATH/config.ovpn"
  #exitOnError $? "Cannot add 'up /etc/openvpn/update-resolv-conf' to $TARGET_PATH/config.ovpn"
  #echo "down /etc/openvpn/update-resolv-conf" >> "$TARGET_PATH/config.ovpn"
  #exitOnError $? "Cannot add 'down /etc/openvpn/update-resolv-conf' to $TARGET_PATH/config.ovpn"
  # Note: TUN device re-opening will restart the container due to permissions
  printf "DONE\n"
fi

############################################
# NETWORKING
############################################
printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Finding network properties...\n"
printf " * Detecting default gateway..."
DEFAULT_GATEWAY=$(ip r | grep 'default via' | cut -d" " -f 3)
exitOnError $?
printf "$DEFAULT_GATEWAY\n"
printf " * Detecting local interface..."
INTERFACE=$(ip r | grep 'default via' | cut -d" " -f 5)
exitOnError $?
printf "$INTERFACE\n"
printf " * Detecting local subnet..."
SUBNET=$(ip r | grep -v 'default via' | grep "$INTERFACE" | tail -n 1 | cut -d" " -f 1)
exitOnError $?
printf "$SUBNET\n"
for EXTRASUBNET in $(echo $EXTRA_SUBNETS | sed "s/,/ /g")
do
  printf " * Adding $EXTRASUBNET as route via $INTERFACE..."
  ip route add $EXTRASUBNET via $DEFAULT_GATEWAY dev $INTERFACE
  exitOnError $?
  printf "DONE\n"
done
printf " * Detecting target VPN interface..."
if [ "$VPN_CLIENT" = "wireguard" ]; then
  VPN_DEVICE="pia"
else
  VPN_DEVICE=$(cat $TARGET_PATH/config.ovpn | grep 'dev ' | cut -d" " -f 2)0
fi
exitOnError $?
printf "$VPN_DEVICE\n"

############################################
# FIREWALL
############################################
printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Checking firewall\n"
if [ "$(readlink -f $(which iptables))" = "$IPTABLES_LEGACY" ]; then
  printf " * Current mode: Legacy\n"
  FIREWALL_MODE="legacy"
elif [ "$(readlink -f $(which iptables))" = "$IPTABLES_LEGACY_ALPINE" ]; then
  printf " * Current mode: Legacy\n"
  FIREWALL_MODE="legacy"
else
  printf " * Current mode: Normal (nftables)\n"
  FIREWALL_MODE="normal"
fi

if [ "$FIREWALL_MODE" = "legacy" ] && [ "$LEGACY_IPTABLES" = "true" ]; then
  printf " * iptables set to preferred\n"
elif [ "$FIREWALL_MODE" = "normal" ] && [ "$LEGACY_IPTABLES" = "false" ]; then
  printf " * iptables set to preferred\n"
else
  printf " * Updating iptables to preferred\n"
  if [ "$LEGACY_IPTABLES"  = "true" ]; then 
    if [ "$(grep ^NAME= /etc/os-release | cut -d '=' -f 2 | tr -d '"')" = "Alpine Linux" ]; then 
      printf "   * OS Detected as Alpine\n"
      printf "   * Switching to legacy iptables..."
      ln -sf "$IPTABLES_LEGACY_ALPINE" /usr/sbin/iptables
      exitOnError $?
      printf "Done\n"
    else
      printf "   * OS Detected as Ubuntu\n"
      printf "   * Switching to legacy iptables..."
      ln -sf "$IPTABLES_LEGACY" /usr/sbin/iptables
      ln -sf "$IP6TABLES_LEGACY" /usr/sbin/ip6tables
      exitOnError $?
      printf "Done\n"
    fi
  else
    if [ "$(grep ^NAME= /etc/os-release | cut -d '=' -f 2 | tr -d '"')" = "Alpine Linux" ]; then 
      printf "   * OS Detected as Alpine\n"
      printf "   * Switching to normal iptables..."
      ln -sf "$IPTABLES_NFT_ALPINE" /sbin/iptables
      exitOnError $?
      printf "Done\n"
    else
      printf "   * OS Detected as Ubuntu\n"
      printf "   * Switching to normal iptables..."
      ln -sf "$IPTABLES_NFT" /usr/sbin/iptables
      ln -sf "$IP6TABLES_NFT" /usr/sbin/ip6tables
      exitOnError $?
      printf "Done\n"
    fi
  fi
fi
printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Setting firewall\n"
printf " * Blocking everything\n"
printf "   * Deleting all iptables rules..."
OUTPUT=$(iptables --flush 2>&1)
exitOnError $? "$OUTPUT"
OUTPUT=$(iptables --delete-chain 2>&1)
exitOnError $? "$OUTPUT"
OUTPUT=$(iptables -t nat --flush 2>&1)
exitOnError $? "$OUTPUT"
OUTPUT=$(iptables -t nat --delete-chain 2>&1)
exitOnError $? "$OUTPUT"
printf "DONE\n"
printf "   * Block input traffic..."
OUTPUT=$(iptables -P INPUT DROP 2>&1)
exitOnError $? "$OUTPUT"
printf "DONE\n"
printf "   * Block output traffic..."
OUTPUT=$(iptables -F OUTPUT 2>&1)
exitOnError $? "$OUTPUT"
OUTPUT=$(iptables -P OUTPUT DROP 2>&1)
exitOnError $? "$OUTPUT"
printf "DONE\n"
printf "   * Block forward traffic..."
OUTPUT=$(iptables -P FORWARD DROP 2>&1)
exitOnError $? "$OUTPUT"
printf "DONE\n"
printf "   * Block all IPv6 traffic..."
# Block IPv6 for BOTH VPN clients. The previous fallback branch only PRINTED that
# it had disabled IPv6 via sysctl - it never actually ran sysctl. That left a real
# leak: the sysctl disable elsewhere is inside the WireGuard-only block, so an
# OpenVPN container whose ip6tables was unavailable had IPv6 neither firewalled nor
# disabled, while the log claimed otherwise. Now the fallback really runs, and if
# IPv6 cannot be blocked at all we fail closed rather than leak.
if ip6tables -F 2>/dev/null && ip6tables -P INPUT DROP 2>/dev/null && ip6tables -P OUTPUT DROP 2>/dev/null && ip6tables -P FORWARD DROP 2>/dev/null; then
  printf "DONE\n"
elif [ ! -f /proc/net/if_inet6 ]; then
  printf "DONE (no IPv6 stack present)\n"
else
  sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
  sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
  # BOTH keys must be checked. "default" is the template new interfaces inherit,
  # and this runs before the tunnel exists - so verifying only "all" would let the
  # VPN interface come up IPv6-enabled while the log reported success.
  v6_all=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)
  v6_def=$(sysctl -n net.ipv6.conf.default.disable_ipv6 2>/dev/null)
  if [ "$v6_all" = "1" ] && [ "$v6_def" = "1" ]; then
    printf "ip6tables unavailable - IPv6 disabled via sysctl instead\n"
  else
    printf "FAILED\n"
    printf "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] Cannot block IPv6: ip6tables is unavailable, and sysctl cannot disable it because Docker mounts /proc/sys read-only. Refusing to start rather than risk an IPv6 leak.\n"
    printf "          Fix: set these when CREATING the container (Docker applies them at creation, before /proc/sys is locked):\n"
    printf "            --sysctl net.ipv6.conf.all.disable_ipv6=1 --sysctl net.ipv6.conf.default.disable_ipv6=1\n"
    printf "          docker-compose users: use the sysctls: block. See Known Issues in the README.\n"
    exit 1
  fi
fi

printf " * Creating general rules\n"
printf "   * Accept established and related input and output traffic..."
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
exitOnError $?
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
exitOnError $?
printf "DONE\n"
printf "   * Accept local loopback input and output traffic..."
iptables -A OUTPUT -o lo -j ACCEPT
exitOnError $?
iptables -A INPUT -i lo -j ACCEPT
exitOnError $?
printf "DONE\n"

# Set the default WebUI interface
if [ -z $WEBUI_INTERFACES ]; then
  WEBUI_INTERFACES=$INTERFACE
fi

printf " * Creating rules for webui-port:$WEBUI_PORT\n"
# Loop through each WebUI interface
for webui_interface in  $(echo $WEBUI_INTERFACES | sed "s/,/ /g"); do
  # Apply OUTPUT rules (allow outgoing traffic on WEBUI_PORT)
  printf "   * * Applied iptables rules for webui on interface: $webui_interface..."
  iptables -A OUTPUT -o "$webui_interface" -p tcp --dport "$WEBUI_PORT" -j ACCEPT
  iptables -A OUTPUT -o "$webui_interface" -p tcp --sport "$WEBUI_PORT" -j ACCEPT
  # Apply INPUT rules (allow incoming traffic on WEBUI_PORT)
  iptables -A INPUT -i "$webui_interface" -p tcp --dport "$WEBUI_PORT" -j ACCEPT
  iptables -A INPUT -i "$webui_interface" -p tcp --sport "$WEBUI_PORT" -j ACCEPT
  printf "DONE\n"
done

# Optionally open extra LAN ports. This is for the common setup where another
# container shares this one's network namespace (network_mode: container:...) to
# route its traffic through the VPN - without this, its ports are unreachable
# because the kill switch drops everything not explicitly allowed. Only INPUT
# rules on the physical interface are added: the return traffic is already covered
# by the established/related rule, and nothing here creates a path out of the
# tunnel, so the kill switch is not weakened.
if [ -n "$OPEN_ADDITIONAL_LOCAL_PORTS" ]; then
  printf " * Opening additional LAN ports: $OPEN_ADDITIONAL_LOCAL_PORTS\n"
  for webui_interface in $(echo $WEBUI_INTERFACES | sed "s/,/ /g"); do
    for opened_port in $(echo $OPEN_ADDITIONAL_LOCAL_PORTS | sed "s/,/ /g"); do
      case "$opened_port" in
        *[!0-9]*|"")
          printf "   * * Skipping invalid port '$opened_port'\n"
          continue
          ;;
      esac
      printf "   * * Opening port $opened_port on interface: $webui_interface..."
      iptables -A INPUT -i "$webui_interface" -p tcp --dport "$opened_port" -j ACCEPT
      printf "DONE\n"
    done
  done
fi

printf " * Creating VPN routes..."
ip rule add from $(ip route get 1 | sed -n 's/.*src \([^ ]*\).*/\1/p') table 128
#if [ "$VPN_CLIENT" = "wireguard" ]; then
#fi
ip route add table 128 to $(ip route get 1 | sed -n 's/.*src \([^ ]*\).*/\1/p')/32 dev $(ip -4 route ls | grep default | sed -n 's/.*dev \([^ ]*\).*/\1/p')
ip route add table 128 default via $(ip -4 route ls | grep default | sed -n 's/.*via \([^ ]*\).*/\1/p')
printf "DONE\n"

printf " * Creating VPN rules\n"
for ip in $VPNIPS; do
  printf "   * * Accept output traffic to VPN server $ip through $INTERFACE, port $PORT..."
  iptables -A OUTPUT -d $ip -o $INTERFACE -p udp -m udp --dport $PORT -j ACCEPT
  iptables -A OUTPUT -d $ip -o $INTERFACE -p tcp -m tcp --dport $PORT -j ACCEPT
  exitOnError $?
  printf "DONE\n"
done

printf "   * Accept all output traffic through $VPN_DEVICE..."
iptables -A OUTPUT -o $VPN_DEVICE -j ACCEPT
exitOnError $?
printf "DONE\n"

printf "   * Clamping TCP MSS on $VPN_DEVICE to path MTU (improves throughput, esp. WireGuard)..."
iptables -t mangle -F POSTROUTING 2>/dev/null || true
if iptables -t mangle -A POSTROUTING -o $VPN_DEVICE -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null; then
  printf "DONE\n"
else
  printf "SKIPPED (TCPMSS unavailable)\n"
fi


if [ "$ALLOW_LOCAL_SUBNET_TRAFFIC" = "true" ]; then
  printf " * Creating local subnet rules\n"
  printf "   * Accept input and output traffic to and from $SUBNET..."
  iptables -A INPUT -s $SUBNET -d $SUBNET -j ACCEPT
  iptables -A OUTPUT -s $SUBNET -d $SUBNET -j ACCEPT
  printf "DONE\n"
fi

for EXTRASUBNET in $(echo $EXTRA_SUBNETS | sed "s/,/ /g")
do
  printf "   * Accept input traffic through $INTERFACE from $EXTRASUBNET to $SUBNET..."
  iptables -A INPUT -i $INTERFACE -s $EXTRASUBNET -d $SUBNET -j ACCEPT
  exitOnError $?
  printf "DONE\n"
  # iptables -A OUTPUT -d $EXTRASUBNET -j ACCEPT
  # iptables -A OUTPUT -o $INTERFACE -s $SUBNET -d $EXTRASUBNET -j ACCEPT
done

############################################
# VPN LAUNCH
############################################
printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Connecting to VPN\n"

mkdir -p "$VPN_LOG_DIR"
cd "$TARGET_PATH"

if [ "$VPN_CLIENT" = "wireguard" ]; then
  printf " * Bringing up Wireguard\n"
  doas -u root wg-quick up pia > "$VPN_LOG_DIR/wireguard.log" 2>&1
  # Mark WireGuard's own encrypted transport and route ONLY that out the physical
  # interface (table 128), so it cannot loop back into the tunnel - that loop is
  # what killed the tunnel after a few minutes. Crucially, unlike a /32 route to
  # the server IP, this leaves the PF API (same server IP, port 19999) flowing
  # THROUGH the tunnel, which PIA requires (else it returns "Unauthorized client").
  wg set pia fwmark 51820
  ip rule add fwmark 51820 table 128 priority 100 2>/dev/null
  ip route add 0.0.0.0/1 dev pia
  ip route add 128.0.0.0/1 dev pia
  ip route flush cache 2>/dev/null

else
  printf " * Opening OpenVPN\n"
  openvpn --config config.ovpn --daemon --log "$VPN_LOG_DIR/openvpn.log" "$@"
fi

############################################
# qBittorrent config
############################################
printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Checking qBittorrent config\n"
QBT_CONF=/config/qBittorrent/config/qBittorrent.conf
# Regenerate the config if it is missing, empty, or does not look like a real
# qBittorrent config. Previously only the "missing" case was handled, so a
# truncated or corrupted file (power loss mid-write, full disk) was left in place,
# then rewritten by the sed calls below, and qBittorrent would fail to start or
# come up with broken settings. A damaged config is now moved aside rather than
# silently discarded, so the user can recover anything from it.
if [ ! -s "$QBT_CONF" ] || ! grep -q "^\[Preferences\]" "$QBT_CONF" 2>/dev/null; then
  if [ -f "$QBT_CONF" ]; then
    QBT_CONF_BACKUP="$QBT_CONF.bak.$(date +%Y%m%d_%H%M%S)"
    mv "$QBT_CONF" "$QBT_CONF_BACKUP"
    printf " * Existing qBittorrent config was empty or unreadable - backed up to %s\n" "$QBT_CONF_BACKUP"
  fi
  mkdir -p /config/qBittorrent/config && cp /app/qBittorrent.conf "$QBT_CONF"
  chmod 755 "$QBT_CONF"
  printf " * Copying default qBittorrent config\n"
fi

# Updating config with user prefrences 
# Bind qBittorrent to the actual VPN interface (pia for WireGuard, tun0 for OpenVPN)
printf " * Setting qBittorrent network interface to $VPN_DEVICE\n"
sed -i "s/Session\\\Interface=.*/Session\\\Interface=$VPN_DEVICE/g" /config/qBittorrent/config/qBittorrent.conf
sed -i "s/Session\\\InterfaceName=.*/Session\\\InterfaceName=$VPN_DEVICE/g" /config/qBittorrent/config/qBittorrent.conf

if [ "${HOSTHEADERVALIDATION}" = "true" ] || [ "${HOSTHEADERVALIDATION}" = "false" ]; then
  printf " * Updating HostHeaderValidation to $HOSTHEADERVALIDATION\n"
  sed -i "s/WebUI\\\HostHeaderValidation=\(true\|false\)/WebUI\\\HostHeaderValidation=$HOSTHEADERVALIDATION/g" /config/qBittorrent/config/qBittorrent.conf
fi

if [ "${CSRFPROTECTION}" = "true" ] || [ "${CSRFPROTECTION}" = "false" ]; then
  printf " * Updating CSRFProtection to $CSRFPROTECTION\n"
  sed -i "s/WebUI\\\CSRFProtection=\(true\|false\)/WebUI\\\CSRFProtection=$CSRFPROTECTION/g" /config/qBittorrent/config/qBittorrent.conf
fi

# Publish the image version as an X-Docker-Version response header (read by qbittorrent-desktop)
printf " * Publishing image version %s via X-Docker-Version header\n" "${CONTAINER_VERSION:-unknown}"
sed -i "s/WebUI\\\CustomHTTPHeaders=.*/WebUI\\\CustomHTTPHeaders=X-Docker-Version: ${CONTAINER_VERSION:-unknown}/g" /config/qBittorrent/config/qBittorrent.conf
sed -i "s/WebUI\\\CustomHTTPHeadersEnabled=.*/WebUI\\\CustomHTTPHeadersEnabled=true/g" /config/qBittorrent/config/qBittorrent.conf

# Set user and group id
if [ -n "$PUID" ]; then
    sed -i "s|^qbtUser:x:[0-9]*:|qbtUser:x:$PUID:|g" /etc/passwd
fi

if [ -n "$PGID" ]; then
    sed -i "s|^\(qbtUser:x:[0-9]*\):[0-9]*:|\1:$PGID:|g" /etc/passwd
    sed -i "s|^qbtUser:x:[0-9]*:|qbtUser:x:$PGID:|g" /etc/group
fi

# Set ownership and permissions of config folder so qBittorrent can read/write it
if [ "$(stat -c '%u' /config 2>/dev/null)" != "$PUID" ]; then
  chown qbtUser:qbtUser -R /config
  chmod 700 -R /config
fi

# Wait until vpn is up
printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Waiting for VPN to connect"
looping=1
while : ; do
	if [ "$VPN_CLIENT" = "wireguard" ]; then
	  # WireGuard: require a completed handshake, not just that the interface exists
	  hs=$(wg show pia latest-handshakes 2>/dev/null | awk 'NR==1{print $2}')
	  if [ -n "$hs" ] && [ "$hs" -gt 0 ] 2>/dev/null; then tunnelstat="up"; else tunnelstat=""; fi
	else
	  tunnelstat=$(ifconfig | grep -E "tun|tap")
	fi
	if [ ! -z "${tunnelstat}" ]; then
		break
	else
    # Search for lines containing 'ERROR:'
    if [ "$VPN_CLIENT" = "wireguard" ]; then
      ERROR_LINES=$(grep "ERROR:" "$VPN_LOG_DIR/wireguard.log")
      AUTH_ERROR_LINES=""
    else
      ERROR_LINES=$(grep "ERROR:" "$VPN_LOG_DIR/openvpn.log")
      AUTH_ERROR_LINES=$(grep "AUTH_FAILED" "$VPN_LOG_DIR/openvpn.log")
    fi

    if [ -n "$ERROR_LINES" ] && [ "$VPN_CLIENT" = "openvpn" ]; then
      # If errors are found, print the openvpn log
      printf "\n"
      printf "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] OpenVPN has encounted an error, see log below and check\n"
      printf "https://github.com/GeorgeAL78/pia-qbittorrent-docker/issues \n"
      printf "---------------------------------------\n"
      printf "$(cat "$VPN_LOG_DIR/openvpn.log")\n"
      ERROR_LINES=$(grep "fatal error" "$VPN_LOG_DIR/openvpn.log")
      if [ -n "$ERROR_LINES" ]; then
        exit 6
      fi
      sleep 30
    elif [ -n "$AUTH_ERROR_LINES" ] && [ "$VPN_CLIENT" = "openvpn" ]; then
        printf "\n"
        printf "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] VPN Authentication Failed. Check your PIA username and password"
        exit 7
    else
      if [ "$looping" -gt 120 ]; then
        # Been waiting 2 mins, someting mins be wrong
        printf "\n"
        printf "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] Unable to connect to VPN. Check your network connection, PIA username and password"
        exit 7
      else
        # If no errors found, waiting a bit longer
        printf "."
        sleep 1
      fi
    fi
	fi
  looping=$((looping + 1))
done
printf "\n"

############################################
# Port Forwarding
############################################
PF_GATEWAY=""
PF_CERT=""
PF_CONNECT=""
# Determine the VPN gateway/connect params unconditionally - needed for the
# tunnel-liveness check later regardless of whether port forwarding itself
# is enabled, not just when PORT_FORWARDING=true.
if [ "$VPN_CLIENT" = "wireguard" ]; then
  PF_GATEWAY=$wg_cn
  PF_CERT="--cacert /app/ca.rsa.4096.crt"
  PF_CONNECT="--connect-to $wg_cn::$wg_ip:"
else
  # The OpenVPN port-forward endpoint is the tunnel gateway. Its certificate IS
  # issued by PIA's CA, but carries the server hostname (e.g. montreal434), so a
  # request addressed to the gateway IP fails hostname validation - which is why
  # this previously fell back to -k and verified nothing at all. Read the CN from
  # the certificate the gateway presents, then make the real requests verified
  # against the bundled PIA CA using --connect-to, exactly as the WireGuard path
  # does. The CN is only used for hostname matching: the trust anchor is still the
  # bundled CA, so a certificate not signed by PIA is still rejected.
  # $VPN_DEVICE, not a hardcoded tun0, so this cannot drift from pf_repin().
  pf_ip=$(route -n | grep UG | grep "$VPN_DEVICE" | tr -s ' ' | cut -d' ' -f2 | head -1)
  PF_GATEWAY="$pf_ip"
  # The certificate probe is only needed for port forwarding, so it is deferred to
  # pf_setup_openvpn_tls below rather than run on every start. tunnel_alive() does
  # NOT need it: its OpenVPN branch only checks the process and interface.
fi

# Resolve TLS parameters for the OpenVPN port-forward endpoint. Called only when
# port forwarding is actually in use.
#
# The endpoint is the tunnel gateway, whose certificate is issued by PIA's CA but
# carries the server hostname, so addressing it by IP fails hostname validation -
# which is why this once used -k and verified nothing. We read the CN the gateway
# presents and then verify properly against the bundled CA.
#
# LIMITATION, deliberately accepted: because the CN comes from the peer rather than
# from an authenticated source, this proves "a host holding a PIA-signed certificate"
# rather than "this specific server". The WireGuard path is stronger, as its CN comes
# from data.json. Pinning here would require parsing the chosen remote out of the
# OpenVPN log and matching it against data.json; the peer IP is not always present in
# that list, so it is not a drop-in. This is still a large improvement over -k, which
# accepted any certificate at all.
pf_setup_openvpn_tls() {
  [ "$VPN_CLIENT" = "wireguard" ] && return 0
  pf_cn=$(curl -sv -k --connect-timeout 5 --max-time 10 "https://$pf_ip:19999/" 2>&1 | grep -oE 'CN=[A-Za-z0-9_.-]+' | head -1 | cut -d= -f2)
  if [ -n "$pf_cn" ]; then
    PF_GATEWAY="$pf_cn"
    PF_CONNECT="--connect-to $pf_cn::$pf_ip:"
    PF_CERT="--cacert /app/ca.rsa.4096.crt"
    return 0
  fi
  # Refuse to fall back to unverified TLS: skipping port forwarding is better than
  # binding a port over a connection we cannot authenticate. Same stance as the
  # IPv6 handling above.
  printf "[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] Could not read the port-forward gateway certificate - skipping port forwarding rather than using unverified TLS\n"
  return 1
}

if is_enabled "$PORT_FORWARDING"; then
  if ! pf_setup_openvpn_tls; then
    PORT_FORWARDING=false
  fi
fi

if is_enabled "$PORT_FORWARDING"; then
  printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Setting up port forwarding\n"

  # Setup the port forwading parameters depending on the VPN client
  if [ "$VPN_CLIENT" = "wireguard" ]; then
    printf " * Using Wireguard port forwarding\n"
  else
    printf " * Using OpenVPN port forwarding\n"
  fi

  # Get a token from PIA to authenticate the port forwarding request
  # --location just to follow redirects
  piaToken=$(curl --connect-timeout 8 --max-time 15 -s --location --request POST \
            'https://www.privateinternetaccess.com/api/client/v2/token' \
            --form "username=$(sed '1!d' /auth.conf)" \
            --form "password=$(sed '2!d' /auth.conf)" | jq -r '.token')
  if [ ! -z "$piaToken" ]; then
    printf " * Got PIA token\n"
  fi

  # Does this region support port forwarding? (all US regions do not.) Looked up
  # from the bundled server list so it works for BOTH WireGuard and OpenVPN
  # ($regiondata is only set for WireGuard; $server is set before the VPN split).
  pf_supported=$(jq -r --arg SERVER "$server" '
                  def normalize: gsub("[_-]"; " ") | ascii_downcase | gsub("\\s+"; " ");
                  ($SERVER | normalize) as $search |
                  [.regions[] | 
                  select((.name | normalize | contains($search)) or (.id | normalize | contains($search)))] |
                  if length > 0 then .[0].port_forward else empty end' /app/data.json 2>/dev/null)
  pf_status=""
  pf_ec=0
  pf_try=0
  pia_sig=""
  if [ "$pf_supported" = "false" ]; then
    printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Region '$PIA_REGION' does not support port forwarding (all US regions lack it) - continuing without it\n"
    printf "          See https://github.com/GeorgeAL78/pia-qbittorrent-docker#pia-regions to pick a PF-capable region\n"
    pf_status="UNSUPPORTED"
  else
    # Get the signature and payload. Right after the tunnel comes up the PF API can
    # need a few seconds before it will issue a signature (route settling on our side,
    # peer registration on PIA's side), so retry instead of giving up on the first try.
    while [ $pf_try -lt 6 ]; do
      pf_try=$((pf_try + 1))
      pia_sig=$(curl --connect-timeout 8 --max-time 15 --get -s \
                $PF_CONNECT \
                $PF_CERT \
                --data-urlencode "token=$piaToken" \
                "https://$PF_GATEWAY:19999/getSignature")
      pf_ec=$?
      pf_status=$(echo "$pia_sig" | jq -r '.status' 2>/dev/null)
      [ "$pf_status" = "OK" ] && break
      if [ $pf_try -lt 6 ]; then
        printf " * Port forwarding API not ready yet (attempt $pf_try/6, curl exit $pf_ec) - retrying in 4s\n"
        sleep 4
      fi
    done
  fi

  if [ "$pf_status" != "OK" ]; then
    if [ "$pf_status" != "UNSUPPORTED" ]; then
      printf "[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] Port forwarding could not be established for region '$PIA_REGION' after $pf_try attempts (last curl exit $pf_ec, status '$pf_status') - continuing without it\n"
      printf "          The PF API stayed unreachable; your kill switch is unaffected. Try a restart or another region.\n"
    fi
    PORT_FORWARDING=false
  else
    signature=$(echo "$pia_sig" | jq -r '.signature')
    if [ ! -z "$signature" ]; then
      printf " * Got signature\n"
    fi

    payload=$(echo "$pia_sig" | jq -r '.payload')
    payloadDecoded=$(echo "$payload" | base64 -d | jq)
    if [ ! -z "$payloadDecoded" ]; then
      printf " * Decoded payload\n"
    fi

    PF_PORT=$(echo "$payloadDecoded" | jq -r '.port')
    if [ ! -z "$PF_PORT" ]; then
      printf " * Your Forwarding port is $PF_PORT\n"
    fi

    # Request port forwarding
    binding=$(curl --connect-timeout 8 --max-time 15 -sG \
              $PF_CONNECT \
              $PF_CERT \
              --data-urlencode "payload=$payload" \
              --data-urlencode "signature=$signature" \
              https://$PF_GATEWAY:19999/bindPort)

    printf " * $(echo $binding | jq -r '.message')\n"

    if [ "$(echo "$binding" | jq -r '.status')" = "OK" ]; then
      # Port bound - open it on the firewall and write it to qBittorrent
      printf " * Adding port to firewall on interface $VPN_DEVICE\n"
      iptables -A INPUT -i $VPN_DEVICE -p tcp --dport $PF_PORT -j ACCEPT
      iptables -A INPUT -i $VPN_DEVICE -p udp --dport $PF_PORT -j ACCEPT
      exitOnError $?

      printf " * Updating port in qBittorrent config\n"
      sed -i "s/Session\\\Port=[0-9]*/Session\\\Port=$PF_PORT/g" /config/qBittorrent/config/qBittorrent.conf
    else
      printf "[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] Port forwarding bind failed - continuing without it\n"
      printf "          $(echo $binding)\n"
      PORT_FORWARDING=false
    fi
  fi
fi

############################################
# Run post-vpn-connect hook script
############################################

# Run the user hook.
#
# SECURITY: this was originally sourced ("."), executing inside this root shell, so
# anything able to write /config - which is chowned to qbtUser, including a
# compromised qBittorrent - obtained root on the next start. A later attempt
# inspected the file owner/mode first, but that is inherently racy: stat and sh
# resolve the path independently and qbtUser owns the directory, so the entry can be
# swapped (or pointed at a symlink) between the check and the exec. A check-then-run
# on a user-writable path cannot be made safe, so the privilege decision is removed
# entirely: the /config hook ALWAYS runs as qbtUser.
#
# A hook that genuinely needs root must live at /app/post-vpn-connect.sh - a path the
# container user cannot write (mount it read-only, or bake it into a derived image).
#
# Environment: a subprocess inherits only EXPORTED variables, and doas scrubs the
# environment outright, so the values hooks actually use are passed explicitly.
# Sourcing used to expose all of them; this keeps documented hooks working.
# Passed as separate quoted assignments, NOT as one string: PIA_REGION is
# user-supplied and may legitimately contain a space ("CA Montreal" resolves the
# same as ca_montreal). Word-splitting one string made env treat "Montreal" as the
# command to run, so the hook did not run at all - exit 127, silently.

if [ -f /app/post-vpn-connect.sh ]; then
  printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Running /app/post-vpn-connect.sh (as root)\n"
  env PF_PORT="$PF_PORT" WEBUI_PORT="$WEBUI_PORT" VPN_DEVICE="$VPN_DEVICE" \
      PIA_REGION="$PIA_REGION" VPN_CLIENT="$VPN_CLIENT" PUID="$PUID" PGID="$PGID" \
      sh /app/post-vpn-connect.sh
fi

if [ -f /config/post-vpn-connect.sh ]; then
  printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Running post-vpn-connect.sh (as qbtUser)\n"
  doas -u qbtUser env PF_PORT="$PF_PORT" WEBUI_PORT="$WEBUI_PORT" VPN_DEVICE="$VPN_DEVICE" \
      PIA_REGION="$PIA_REGION" VPN_CLIENT="$VPN_CLIENT" PUID="$PUID" PGID="$PGID" \
      sh /config/post-vpn-connect.sh
fi
# Checks the VPN tunnel is actually alive, independent of PORT_FORWARDING -
# this is what catches a tunnel that stays "up" (interface present) but has
# quietly stopped passing traffic, which otherwise shows no error and just
# hangs. NOTE: an earlier version of this probed the PIA gateway's port-
# forward endpoint (:19999) as a generic reachability signal, on the theory
# that any response (even an auth error) proves the tunnel is up. That broke
# on regions that do not support port forwarding (all US regions): if PIA
# simply does not run that service there, the probe fails on a perfectly
# healthy tunnel, triggering needless reconnects and eventually an
# unnecessary container restart. Use signals that do not depend on a
# region-specific external service instead.
tunnel_alive() {
  if [ "$VPN_CLIENT" = "wireguard" ]; then
    # WireGuard exposes handshake freshness locally, no network call needed,
    # and it is available regardless of region/PF support. PersistentKeepalive
    # is 25s, so a healthy tunnel's handshake should never be much older than
    # that; allow generous slack for jitter.
    # NOTE: healthcheck.sh implements the same check with a larger threshold (180s
    # vs 150s here). The values differ deliberately: this runs inside the 10-minute
    # monitoring loop and a failure triggers a reconnect, whereas healthcheck.sh
    # runs every minute and Docker retries it 3 times before marking the container
    # unhealthy. Keep both in step if either changes.
    hs=$(wg show pia latest-handshakes 2>/dev/null | awk 'NR==1{print $2}')
    [ -z "$hs" ] && return 1
    [ "$hs" -gt 0 ] 2>/dev/null || return 1
    now=$(date +%s)
    age=$((now - hs))
    [ "$age" -lt 150 ]
  else
    # OpenVPN has no equivalent built-in freshness signal without a management
    # socket. Fall back to confirming the process and interface are present -
    # weaker than a true traffic check, but does not risk false positives on a
    # healthy tunnel the way an external, region-specific probe can.
    pgrep -x openvpn > /dev/null && ifconfig 2>/dev/null | grep -q "$VPN_DEVICE"
  fi
}

# Reconnect the VPN in place (no container restart), triggered either by a
# failed port-forward refresh or by tunnel_alive() detecting a dead tunnel.
# Re-establishes the tunnel and, if port forwarding is in use, re-binds the
# SAME port (reused payload/signature) so qBittorrent keeps running and its
# configured port stays valid.
# Re-register a fresh WireGuard key with PIA using the EXISTING token, then rewrite
# /etc/wireguard/pia.conf. A WireGuard tunnel can die because the PIA server dropped
# our key registration (e.g. the server restarted); re-upping the same config then
# loops forever (seen live: 100+ failed reconnects). addKey re-registers the key and
# targets the SAME server IP:port the kill switch already permits, so it works with
# the tunnel down and needs no firewall change (leak-safe). NOTE: we deliberately do
# NOT fetch a fresh *token* here - the token endpoint is privateinternetaccess.com,
# not the VPN server, so the kill switch (correctly) blocks it while the tunnel is
# down. If the token itself has expired, this returns non-zero and only a container
# restart (which re-runs startup and gets a new token before the firewall is built)
# can recover. Returns 0 on success.
wg_refresh_config() {
  [ -z "$piatoken" ] && return 1
  refresh_pk="$(wg genkey)"
  refresh_pub="$(echo "$refresh_pk" | wg pubkey)"

  # Try each server in the region until one registers the key. The default
  # server is first; the rest are failover targets for when it is down or has
  # been decommissioned (retrying only the dead server would never recover).
  refresh_json=""
  for_ip=""
  for_cn=""
  echo "$WG_SERVERS" | while read -r s_ip s_cn; do
    [ -z "$s_ip" ] && continue
    r="$(curl -s --connect-timeout 8 --max-time 15 -G --connect-to "$s_cn::$s_ip:" --cacert /app/ca.rsa.4096.crt --data-urlencode "pt=$piatoken" --data-urlencode "pubkey=$refresh_pub" "https://$s_cn:$wg_port/addKey")"
    if [ "$(echo "$r" | jq -r '.status' 2>/dev/null)" = "OK" ]; then
      printf '%s\n' "$r" > /tmp/.wg_refresh.json
      printf '%s %s\n' "$s_ip" "$s_cn" > /tmp/.wg_refresh.server
      break
    fi
  done
  [ -s /tmp/.wg_refresh.json ] || return 1
  refresh_json="$(cat /tmp/.wg_refresh.json)"
  for_ip="$(awk '{print $1}' /tmp/.wg_refresh.server)"
  for_cn="$(awk '{print $2}' /tmp/.wg_refresh.server)"
  rm -f /tmp/.wg_refresh.json /tmp/.wg_refresh.server
  # Point the live server vars at whichever server accepted us, so the tunnel
  # config and any later refresh use it.
  if [ "$for_ip" != "$wg_ip" ]; then
    printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Failed over to VPN server $for_ip ($for_cn)\n"
  fi
  wg_ip="$for_ip"
  wg_cn="$for_cn"
  WG_IP="$for_ip"
  mkdir -p /etc/wireguard
  cat > /etc/wireguard/pia.conf <<WGEOF
[Interface]
PrivateKey = ${refresh_pk}
Address = $(echo "$refresh_json" | jq -r '.peer_ip')
Table = off

[Peer]
PublicKey = $(echo "$refresh_json" | jq -r '.server_key')
AllowedIPs = 0.0.0.0/0
Endpoint = ${WG_IP}:$(echo "$refresh_json" | jq -r '.server_port')
PersistentKeepalive = 25
WGEOF
  return 0
}

# Re-pin the port-forward gateway after a reconnect. Both VPN clients can come
# back on a DIFFERENT server than they left on - WireGuard because wg_refresh_config
# fails over through the region's server list, OpenVPN because the profile carries
# several remotes - and PF_CONNECT pins the gateway by CN and IP. Left stale, every
# post-failover bindPort is aimed at the server we just abandoned, so the rebind
# fails on a perfectly healthy tunnel and drives the reconnect counter toward the
# restart escalation. Cheap for WireGuard (local values); OpenVPN re-reads the
# route and re-probes the certificate.
pf_repin() {
  if [ "$VPN_CLIENT" = "wireguard" ]; then
    PF_GATEWAY="$wg_cn"
    PF_CONNECT="--connect-to $wg_cn::$wg_ip:"
    return 0
  fi
  # Commit nothing until the whole re-pin succeeds. Writing PF_GATEWAY and
  # PF_CONNECT before the certificate probe left a half-written pin on failure:
  # PF_GATEWAY became the raw gateway IP and PF_CONNECT was cleared, while
  # PF_CERT still held --cacert from startup. Every later request was then an
  # IP-addressed URL verified against a CA whose certificate names a hostname,
  # which can never match - curl exit 60, permanently, until a restart.
  new_ip=$(route -n | grep UG | grep "$VPN_DEVICE" | tr -s ' ' | cut -d' ' -f2 | head -1)
  [ -z "$new_ip" ] && return 1
  new_cn=$(curl -sv -k --connect-timeout 5 --max-time 10 "https://$new_ip:19999/" 2>&1 | grep -oE 'CN=[A-Za-z0-9_.-]+' | head -1 | cut -d= -f2)
  [ -z "$new_cn" ] && return 1
  pf_ip="$new_ip"
  PF_GATEWAY="$new_cn"
  PF_CONNECT="--connect-to $new_cn::$new_ip:"
  PF_CERT="--cacert /app/ca.rsa.4096.crt"
  return 0
}

reconnect_vpn() {
  printf "\n[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] Reconnecting VPN in place (no container restart)\n"
  if [ "$VPN_CLIENT" = "wireguard" ]; then
    doas -u root wg-quick down pia > /dev/null 2>&1
    # The PIA server may have dropped our key registration (e.g. it restarted);
    # re-register a fresh key so the handshake can actually re-establish. If this
    # fails (e.g. the token expired), fall through and retry the existing config.
    if wg_refresh_config; then
      printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Re-registered WireGuard key with PIA\n"
    fi
    doas -u root wg-quick up pia > "$VPN_LOG_DIR/wireguard.log" 2>&1
    wg set pia fwmark 51820 2>/dev/null
    ip rule add fwmark 51820 table 128 priority 100 2>/dev/null
    ip route add 0.0.0.0/1 dev pia 2>/dev/null
    ip route add 128.0.0.0/1 dev pia 2>/dev/null
    ip route flush cache 2>/dev/null
  else
    # OpenVPN has no wg-quick-style down/up - restart the process itself.
    pkill -x openvpn 2>/dev/null
    wait_i=0
    while ifconfig 2>/dev/null | grep -q "$VPN_DEVICE" && [ $wait_i -lt 10 ]; do
      sleep 1
      wait_i=$((wait_i + 1))
    done
    ( cd "$TARGET_PATH" && openvpn --config config.ovpn --daemon --log "$VPN_LOG_DIR/openvpn.log" )
    wait_i=0
    while ! ifconfig 2>/dev/null | grep -q "$VPN_DEVICE" && [ $wait_i -lt 20 ]; do
      sleep 1
      wait_i=$((wait_i + 1))
    done
  fi

  # Wait for the tunnel to actually come up before judging the reconnect.
  # WireGuard needs a few seconds for its first handshake, and the port-forward
  # rebind below runs THROUGH the tunnel, so probing immediately would fail even
  # on a reconnect that is about to succeed.
  wait_i=0
  while [ $wait_i -lt 45 ]; do
    tunnel_alive && break
    sleep 1
    wait_i=$((wait_i + 1))
  done
  if ! tunnel_alive; then
    return 1
  fi

  if is_enabled "$PORT_FORWARDING"; then
    # Point at whichever server we actually came back on before rebinding.
    # A failure here is a port-forwarding problem, NOT a dead tunnel: tunnel_alive
    # confirmed the tunnel is up immediately above. Returning 1 would count a
    # healthy tunnel toward the 6x restart escalation - the very shape this
    # function exists to remove. Startup takes the same stance, skipping port
    # forwarding rather than failing. The pin is left untouched, so the next
    # cycle retries it.
    if ! pf_repin; then
      printf "[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] Reconnected, but could not re-pin the port-forward gateway - port forwarding will be retried next cycle\n"
      return 0
    fi
    binding=$(curl --connect-timeout 8 --max-time 15 -sG $PF_CONNECT $PF_CERT --data-urlencode "payload=$payload" --data-urlencode "signature=$signature" https://$PF_GATEWAY:19999/bindPort)
    if [ "$(echo "$binding" | jq -r '.status')" != "OK" ] && [ -n "$piaToken" ]; then
      # A signature is issued by a specific gateway; after a failover the new one
      # can refuse it. Ask the current gateway for a fresh one and retry once.
      # This runs THROUGH the tunnel (verified up above), so the kill switch is
      # untouched: no firewall change, and the gateway is already in VPNIPS.
      pia_sig=$(curl --connect-timeout 8 --max-time 15 --get -s $PF_CONNECT $PF_CERT --data-urlencode "token=$piaToken" "https://$PF_GATEWAY:19999/getSignature")
      if [ "$(echo "$pia_sig" | jq -r '.status' 2>/dev/null)" = "OK" ]; then
        signature=$(echo "$pia_sig" | jq -r '.signature')
        payload=$(echo "$pia_sig" | jq -r '.payload')
        new_port=$(echo "$payload" | base64 -d | jq -r '.port' 2>/dev/null)
        if [ -n "$new_port" ] && [ "$new_port" != "null" ] && [ "$new_port" != "$PF_PORT" ]; then
          printf "[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] PIA issued a new forwarded port after failover: $new_port (was $PF_PORT)\n"
          printf "          The firewall now allows $new_port, but the RUNNING qBittorrent keeps listening on $PF_PORT,\n"
          printf "          so incoming connections stay closed until the container is restarted.\n"
          iptables -D INPUT -i $VPN_DEVICE -p tcp --dport $PF_PORT -j ACCEPT 2>/dev/null
          iptables -D INPUT -i $VPN_DEVICE -p udp --dport $PF_PORT -j ACCEPT 2>/dev/null
          PF_PORT="$new_port"
          iptables -A INPUT -i $VPN_DEVICE -p tcp --dport $PF_PORT -j ACCEPT
          iptables -A INPUT -i $VPN_DEVICE -p udp --dport $PF_PORT -j ACCEPT
          # Deliberately NOT written to qBittorrent.conf: qBittorrent keeps its
          # preferences in memory and rewrites that file when it saves, so the edit
          # is reverted (measured: 59999 written, 42940 on disk after the save).
          # The next start requests a fresh port and rewrites it regardless.
        fi
        binding=$(curl --connect-timeout 8 --max-time 15 -sG $PF_CONNECT $PF_CERT --data-urlencode "payload=$payload" --data-urlencode "signature=$signature" https://$PF_GATEWAY:19999/bindPort)
      fi
    fi
    if [ "$(echo "$binding" | jq -r '.status')" = "OK" ]; then
      printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Reconnected - port forwarding restored (port $PF_PORT)\n"
      return 0
    fi
    return 1
  fi

  # No port forwarding in use - the tunnel being back up (verified above) is
  # all a successful reconnect needs.
  printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Reconnected - tunnel is back up\n"
  return 0
}


############################################
# Start qBittorrent
############################################

# Gracefully stop qBittorrent on shutdown (SIGTERM from `docker stop`/update, or SIGINT)
# so it saves resume data — otherwise torrents re-check from 0% on the next start.
graceful_shutdown() {
  printf "\n[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Shutdown signal received - stopping qBittorrent gracefully\n"
  qbt_pid=$(pgrep -x qbittorrent-nox)
  if [ -n "$qbt_pid" ]; then
    kill -TERM "$qbt_pid" 2>/dev/null
    # wait for qBittorrent to finish writing resume data and exit
    while pgrep -x qbittorrent-nox > /dev/null; do
      sleep 1
    done
  fi
  printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] qBittorrent stopped cleanly - resume data saved\n"
  exit 0
}
trap graceful_shutdown TERM INT

printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Launching qBittorrent\n"

# remove the previous lock file if it exists, otherwise qBittorrent won't start
if [ -f /config/qBittorrent/config/lockfile ]; then
  printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Cleaning lock file\n"
  rm /config/qBittorrent/config/lockfile -f
fi

exec doas -u qbtUser sh -c "umask ${UMASK:-022}; exec qbittorrent-nox --webui-port=$WEBUI_PORT --profile=/config" &

i=1
vpn_fail_count=0
tunnel_state=up          # last observed state, for transition logging
tunnel_down_since=0      # epoch seconds when it went down
while : ; do
	sleep 1

  # Sample tunnel health every 30s and log only the transitions, so brief
  # outages (e.g. a modem reboot) that WireGuard heals by itself still leave
  # a trail. Logging only - the 10-min block below owns recovery.
  if [ $((i % 30)) -eq 0 ]; then
    if tunnel_alive; then
      if [ "$tunnel_state" = "down" ]; then
        down_for=$(( $(date +%s) - tunnel_down_since ))
        printf "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Tunnel recovered (was down ~${down_for}s)\n"
        tunnel_state=up
      fi
    else
      if [ "$tunnel_state" = "up" ]; then
        tunnel_down_since=$(date +%s)
        printf "[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] Tunnel went down\n"
        tunnel_state=down
      fi
    fi
  fi

  if [ $i -gt 600 ]; then
    i=1
    need_reconnect=false
    if is_enabled "$PORT_FORWARDING"; then
      binding=$(curl --connect-timeout 8 --max-time 15 -sG \
            $PF_CONNECT \
            $PF_CERT \
            --data-urlencode "payload=$payload" \
            --data-urlencode "signature=$signature" \
            https://$PF_GATEWAY:19999/bindPort)

#      now just for debugging
#      printf "Port Forwarding - $(echo $binding | jq -r '.message')\n"

      if [ "$(echo "$binding" | jq -r '.status')" != "OK" ]; then
        printf "[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] Port forwarding refresh failed\n"
        need_reconnect=true
      fi
    else
      # No port forwarding to rebind, but the tunnel itself can still die
      # silently (interface stays up, no error - torrents just hang with no
      # indication why). Verify it is actually passing traffic.
      if ! tunnel_alive; then
        printf "[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] Tunnel appears dead (no response from VPN gateway)\n"
        need_reconnect=true
      fi
    fi

    if [ "$need_reconnect" = "true" ]; then
      if reconnect_vpn; then
        vpn_fail_count=0
      else
        vpn_fail_count=$((vpn_fail_count + 1))
        printf "[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] Reconnect attempt $vpn_fail_count did not restore the connection\n"
        # In-place reconnect re-registers the WireGuard KEY, but it cannot refresh
        # an expired PIA TOKEN - the token endpoint is a different host the kill
        # switch correctly blocks while the tunnel is down. Only a full restart can
        # get a new token (startup fetches one before the firewall is built). So
        # after ~1h of failed in-place attempts - long enough that transient
        # outages have had time to self-heal and an expired token is the likely
        # cause - exit for a clean restart. NOTE: this REQUIRES a restart policy;
        # without one the container stays stopped (docker update --restart
        # unless-stopped <name>). The template sets it for new installs.
        if [ "$vpn_fail_count" -ge 6 ]; then
          printf "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] In-place reconnect failed ${vpn_fail_count}x (~1h) - exiting for a full restart to obtain a fresh PIA token. If the container does not come back, set '--restart unless-stopped'.\n"
          # Save qBittorrent resume data before exiting so torrents do not re-check.
          qbt_pid=$(pgrep -x qbittorrent-nox)
          if [ -n "$qbt_pid" ]; then
            kill -TERM "$qbt_pid" 2>/dev/null
            while pgrep -x qbittorrent-nox > /dev/null; do sleep 1; done
          fi
          exit 5
        fi
      fi
    fi
  fi
  if ! pgrep -x "qbittorrent-nox" > /dev/null
  then
    break
  fi
  i=$((i + 1))
done

