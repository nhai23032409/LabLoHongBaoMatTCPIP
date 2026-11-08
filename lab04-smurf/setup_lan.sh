#!/bin/bash
# setup_lan.sh - Dung LAN 10.0.0.0/24 bang cau (bridge) br0 voi 5 host ao
# nam gon trong 1 may Kali (dung network namespace). Tat ca la mo phong,
# khong dung toi cau hinh mang that cua VMware.
#
#   atk  10.0.0.100   attacker (ke tan cong)
#   vic  10.0.0.200   victim   (nan nhan)
#   amp1 10.0.0.11    may "khuech dai"
#   amp2 10.0.0.12    may "khuech dai"
#   amp3 10.0.0.13    may "khuech dai"
#   Broadcast cua LAN: 10.0.0.255
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

add_host atk  10.0.0.100
add_host vic  10.0.0.200
add_host amp1 10.0.0.11
add_host amp2 10.0.0.12
add_host amp3 10.0.0.13

echo "[+] LAN 10.0.0.0/24 (broadcast 10.0.0.255) da san sang."
echo "    Kiem tra ket noi: sudo ip netns exec atk ping -c2 10.0.0.11"
