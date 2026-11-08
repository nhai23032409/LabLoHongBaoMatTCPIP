#!/bin/bash
# setup_redirect.sh - Dung mo hinh co 1 ROUTER ao cho lab ICMP Redirect.
# Tat ca mo phong bang network namespace trong 1 may Kali (khong dung mang VMware).
#
#  LAN 10.0.0.0/24 (bridge br0):
#     vic 10.0.0.2    victim (nan nhan)
#     gw  10.0.0.1    gateway hop phap (router)
#     atk 10.0.0.66   attacker (cung LAN voi victim)
#
#  Mang "xa" sau router: 10.0.1.0/24
#     gw  10.0.1.254   (cong thu 2 cua router)
#     dst 10.0.1.5     may dich can lien lac toi
#
# Chay (can root): sudo bash setup_redirect.sh
set -e

ip link add br0 type bridge
ip link set br0 up

add_host() {            # $1 = ten namespace, $2 = dia chi IP (tren LAN)
  ns=$1; ipaddr=$2
  ip netns add "$ns"
  ip link add "${ns}0" type veth peer name "${ns}-br"
  ip link set "${ns}-br" master br0; ip link set "${ns}-br" up
  ip link set "${ns}0" netns "$ns"
  ip netns exec "$ns" ip addr add "${ipaddr}/24" dev "${ns}0"
  ip netns exec "$ns" ip link set "${ns}0" up
  ip netns exec "$ns" ip link set lo up
}

add_host vic 10.0.0.2       # victim
add_host gw  10.0.0.1       # gateway hop phap (router)
add_host atk 10.0.0.66      # attacker (cung LAN)

# Lien ket GW <-> dst (mang 10.0.1.0/24 nam sau router)
ip netns add dst
ip link add gw-d type veth peer name d-gw
ip link set gw-d netns gw ; ip link set d-gw netns dst
ip netns exec gw  ip addr add 10.0.1.254/24 dev gw-d ; ip netns exec gw  ip link set gw-d up
ip netns exec dst ip addr add 10.0.1.5/24   dev d-gw ; ip netns exec dst ip link set d-gw up
ip netns exec dst ip link set lo up

# GW chuyen tiep goi, nhung KHONG tu gui redirect (de chi con redirect GIA cua attacker)
ip netns exec gw sysctl -w net.ipv4.ip_forward=1
ip netns exec gw sysctl -w net.ipv4.conf.all.send_redirects=0
ip netns exec gw sysctl -w net.ipv4.conf.gw0.send_redirects=0
ip netns exec gw sysctl -w net.ipv4.conf.gw-d.send_redirects=0

# Dinh tuyen
ip netns exec vic ip route add default via 10.0.0.1
ip netns exec dst ip route add default via 10.0.1.254

# Victim CHAP NHAN redirect (tai tao DIEM YEU)
for k in all vic0; do
  ip netns exec vic sysctl -w net.ipv4.conf.$k.accept_redirects=1
  ip netns exec vic sysctl -w net.ipv4.conf.$k.secure_redirects=0
done

echo "[+] Xong. Kiem tra victim -> 10.0.1.5 (di qua GW hop phap):"
ip netns exec vic ping -c2 10.0.1.5
