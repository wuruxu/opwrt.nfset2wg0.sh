#!/bin/sh
set -e

WG_PRIVATE_KEY=''
WG_PUBLIC_KEY=''
WG_ENDPOINT=''
WG_ENDPOINT_PORT=29008
WG_ADDRESSES='192.168.111.9 fd08:5399:1111::9'

NFT_FILE="/etc/nftables.d/20-mangle-wgset.nft"

cat > "$NFT_FILE" <<'EOF'
chain mangle_prerouting_wgset {
	type filter hook prerouting priority mangle; policy accept;
	ip daddr @wgset meta mark set 0x00003c25 counter accept
	ip6 daddr @wgset6 meta mark set 0x00003c26 counter accept
}

#chain mangle_output_wgset {
chain mangle_output {
	type route hook output priority mangle; policy accept;
	ip daddr @wgset meta mark set 0x00003c25 counter accept
	ip6 daddr @wgset6 meta mark set 0x00003c26 counter accept
}
EOF

echo "Created $NFT_FILE"

check_route_rule_exists() {
  local type="$1"   # rule 或 rule6
  local name="$2"
  local i=0

  while uci -q get network.@${type}[$i] >/dev/null; do
    local n=$(uci -q get network.@${type}[$i].name)
    if [ "$n" = "$name" ]; then
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

add_ipv4_route() {
  local name="$1"
  local iface="$2"
  local target="$3"
  local table="$4"

  if check_route_rule_exists "route" $name; then
    echo "🔁 Skipped: route '$name' already exists"
    return
  fi

  uci add network route
  uci set network.@route[-1].name="$name"
  uci set network.@route[-1].interface="$iface"
  uci set network.@route[-1].target="$target"
  [ -n "$table" ] && uci set network.@route[-1].table="$table"
  echo "✅ Added IPv4 route: $name"
}

add_ipv6_route() {
  local name="$1"
  local iface="$2"
  local target="$3"
  local gateway="$4"
  local table="$5"

  if check_route_rule_exists "route6" $name; then
    echo "🔁 Skipped: route6 '$name' already exists"
    return
  fi

  uci add network route6
  uci set network.@route6[-1].name="$name"
  uci set network.@route6[-1].interface="$iface"
  uci set network.@route6[-1].target="$target"
  [ -n "$gateway" ] && uci set network.@route6[-1].gateway="$gateway"
  [ -n "$table" ] && uci set network.@route6[-1].table="$table"
  echo "✅ Added IPv6 route: $name"
}

add_ipv4_rule() {
  local name="$1"
  local mark="$2"
  local table="$3"

  if check_route_rule_exists "rule" $name; then
    echo "🔁 Skipped: rule '$name' already exists"
    return
  fi

  uci add network rule
  uci set network.@rule[-1].name="$name"
  uci set network.@rule[-1].mark="$mark"
  uci set network.@rule[-1].lookup="$table"
  echo "✅ Added IPv4 rule: $name"
}

add_ipv6_rule() {
  local name="$1"
  local mark="$2"
  local table="$3"

  if check_route_rule_exists "rule6" $name; then
    echo "🔁 Skipped: rule6 '$name' already exists"
    return
  fi

  uci add network rule6
  uci set network.@rule6[-1].name="$name"
  uci set network.@rule6[-1].mark="$mark"
  uci set network.@rule6[-1].lookup="$table"
  echo "✅ Added IPv6 rule: $name"
}

add_firewall_zone_if_not_exists() {
    local zone_name="$1"
    local network="$2"
    local input_policy="${3:-ACCEPT}"
    local output_policy="${4:-ACCEPT}"
    local forward_policy="${5:-ACCEPT}"
    local masq="${6:-1}"
    local masq6="${7:-1}"
    local mtu_fix="${8:-1}"

    local idx=0
    local found=0

    while uci -q get firewall.@zone[$idx] > /dev/null; do
        local name=$(uci -q get firewall.@zone[$idx].name)
        if [ "$name" = "$zone_name" ]; then
            found=1
            break
        fi
        idx=$((idx + 1))
    done

    if [ "$found" -eq 1 ]; then
        echo "Firewall zone '$zone_name' already exists, skipping."
    else
        local new_idx=$(uci add firewall zone)
        uci set firewall.${new_idx}.name="$zone_name"
        uci add_list firewall.${new_idx}.network="$network"
        uci set firewall.${new_idx}.input="$input_policy"
        uci set firewall.${new_idx}.output="$output_policy"
        uci set firewall.${new_idx}.forward="$forward_policy"
        uci set firewall.${new_idx}.masq="$masq"
        uci set firewall.${new_idx}.masq6="$masq6"
        uci set firewall.${new_idx}.mtu_fix="$mtu_fix"
        echo "Added firewall zone '$zone_name'"
    fi
}

add_ipset_if_not_exist() {
    local name="$1"
    local family="$2"
    shift 2
    local entries="$@"

    if uci show firewall | grep -q "firewall.@ipset.*.name='${name}'"; then
        echo "ipset '${name}' already exists, skipping."
    else
        local index=$(uci add firewall ipset)
        uci set firewall.${index}.name="${name}"
        uci set firewall.${index}.match='dest_net'
        uci set firewall.${index}.storage='hash'
        uci set firewall.${index}.family="${family}"
        uci set firewall.${index}.enabled='1'

        for entry in $entries; do
            uci add_list firewall.${index}.entry="${entry}"
        done

        echo "Added ipset '${name}'"
    fi
}

add_firewall_zone_if_not_exists 'wg111'  'wg0'  'ACCEPT'  'ACCEPT'  'ACCEPT'  '1'  '1'  '1'

add_ipset_if_not_exist 'wgset' 'ipv4' \
    '1.1.0.0/16' '8.8.0.0/16' '149.154.0.0/16' '91.108.0.0/16' \
    '74.125.0.0/16' '173.194.0.0/16' '209.85.229.0/24'

add_ipset_if_not_exist 'wgset6' 'ipv6' \
    '2001:4860:4860::8888' '2001:4860:4860::8844'

uci commit firewall

add_interface_if_not_exists() {
    local ifname="$1"
    local proto="$2"
    local private_key="$3"
    local mtu="$4"
    shift 4
    local addresses="$@"

    if uci -q get network.$ifname > /dev/null; then
        echo "[SKIP] Interface '$ifname' already exists."
    else
        uci set network.$ifname="interface"
        uci set network.$ifname.proto="$proto"
        uci set network.$ifname.private_key="$private_key"
        uci set network.$ifname.mtu="$mtu"
        for addr in $addresses; do
            uci add_list network.$ifname.addresses="$addr"
        done
        echo "[ADD] Interface '$ifname'"
    fi
}

add_peer_if_not_exists() {
    local peer_name="$1"
    local iface="$2"
    local public_key="$3"
    local endpoint_host="$4"
    local endpoint_port="$5"
    local allowed_ips="$6"

    if uci -q get network.$peer_name > /dev/null; then
        echo "[SKIP] Peer '$peer_name' already exists."
    else
        uci set network.$peer_name="wireguard_$iface"
        uci set network.$peer_name.public_key="$public_key"
        uci set network.$peer_name.endpoint_host="$endpoint_host"
        uci set network.$peer_name.endpoint_port="$endpoint_port"
        uci set network.$peer_name.persistent_keepalive="60"
        uci set network.$peer_name.route_allowed_ips="0"
        for ip in $allowed_ips; do
            uci add_list network.$peer_name.allowed_ips="$ip"
        done
        echo "[ADD] Peer '$peer_name' (for $iface)"
    fi
}

uci set dhcp.@dnsmasq[0].confdir='/etc/dnsmasq.d/'
uci add_list dhcp.@dnsmasq[0].server='/dnsapi.cn/.cn/114.114.114.114'
uci commit dhcp

add_interface_if_not_exists wg0 wireguard $WG_PRIVATE_KEY 1380 $WG_ADDRESSES
add_peer_if_not_exists wghz  wg0 $WG_PUBLIC_KEY $WG_ENDPOINT $WG_ENDPOINT_PORT '0.0.0.0/0 ::/0'
uci commit network
