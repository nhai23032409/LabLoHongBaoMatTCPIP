#!/bin/bash
# setup_lan.sh - Dung LAN 10.0.0.0/24 bang cau (bridge) br0 voi 4 host ao
# nam gon trong 1 may Kali (dung network namespace). Tat ca la mo phong,
# khong dung toi cau hinh mang that cua VMware.
#
#   auth     10.0.0.10   may chu uy quyen (authoritative) BIND9, zone da ky DNSSEC
#   resolver 10.0.0.20   resolver xac thuc (validating) unbound
#   client   10.0.0.30   may khach chay dig/delv
#   attacker 10.0.0.40   may chu uy quyen GIA MAO (rogue) phuc vu du lieu forged
#
# Chay (can quyen root): sudo bash setup_lan.sh
set -e

ip link add br0 type bridge
ip link set br0 up

add_host() {            # $1 = ten namespace, $2 = dia chi IP
  ns=$1; ipaddr=$2
  ip netns add "$ns"
  ip link add "${ns}0" type veth peer name "${ns}-br"
  ip link set "${ns}-br" master br0
  ip link set "${ns}-br" up
  ip link set "${ns}0" netns "$ns"
  ip netns exec "$ns" ip addr add "${ipaddr}/24" dev "${ns}0"
  ip netns exec "$ns" ip link set "${ns}0" up
  ip netns exec "$ns" ip link set lo up
}

add_host auth     10.0.0.10
add_host resolver 10.0.0.20
add_host client   10.0.0.30
add_host attacker 10.0.0.40

echo "[+] LAN 10.0.0.0/24 da san sang (auth .10, resolver .20, client .30, attacker .40)."
echo "    Kiem tra ket noi: sudo ip netns exec client ping -c2 10.0.0.20"
