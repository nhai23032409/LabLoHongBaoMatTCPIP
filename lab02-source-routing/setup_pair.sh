#!/usr/bin/env bash
set -Eeuo pipefail
if [[ ${EUID} -ne 0 ]]; then echo "[!] Chạy bằng root: sudo ./setup_pair.sh" >&2; exit 1; fi
ip netns del h1 2>/dev/null || true
ip netns del h2 2>/dev/null || true
ip netns add h1
ip netns add h2
ip link add veth1 type veth peer name veth2
ip link set veth1 netns h1
ip link set veth2 netns h2
ip -n h1 addr add 10.0.0.1/24 dev veth1
ip -n h2 addr add 10.0.0.2/24 dev veth2
ip -n h1 link set lo up
ip -n h1 link set veth1 up
ip -n h2 link set lo up
ip -n h2 link set veth2 up
for ns in h1 h2; do
  ip netns exec "$ns" sysctl -qw net.ipv4.conf.all.rp_filter=0
  ip netns exec "$ns" sysctl -qw net.ipv4.conf.default.rp_filter=0
  ip netns exec "$ns" sysctl -qw net.ipv4.conf.all.accept_source_route=1
  ip netns exec "$ns" sysctl -qw net.ipv4.conf.default.accept_source_route=1
done
ip netns exec h1 sysctl -qw net.ipv4.conf.veth1.accept_source_route=1
ip netns exec h1 sysctl -qw net.ipv4.conf.veth1.rp_filter=0
ip netns exec h2 sysctl -qw net.ipv4.conf.veth2.accept_source_route=1
ip netns exec h2 sysctl -qw net.ipv4.conf.veth2.rp_filter=0
echo "[+] Topology ready: h1=10.0.0.1, h2=10.0.0.2"
ip netns exec h1 ping -c 2 -W 1 10.0.0.2
