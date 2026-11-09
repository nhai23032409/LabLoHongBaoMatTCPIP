#!/bin/bash
# setup_pair.sh - Dung 2 namespace noi voi nhau qua 1 lien ket veth.
# Mo phong trong 1 may Kali (khong dung mang VMware).
#   h1 = attacker/observer  10.0.0.1
#   h2 = victim/server      10.0.0.2
# Chay (can root): sudo bash setup_pair.sh
set -e

ip netns add h1
ip netns add h2
ip link add veth1 type veth peer name veth2
ip link set veth1 netns h1
ip link set veth2 netns h2

ip netns exec h1 ip addr add 10.0.0.1/24 dev veth1
ip netns exec h2 ip addr add 10.0.0.2/24 dev veth2
ip netns exec h1 ip link set veth1 up
ip netns exec h2 ip link set veth2 up
ip netns exec h1 ip link set lo up
ip netns exec h2 ip link set lo up

echo "[+] Topo san sang. Kiem tra ket noi:"
ip netns exec h1 ping -c2 10.0.0.2
