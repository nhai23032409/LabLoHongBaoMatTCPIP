#!/bin/bash
# cleanup.sh - Don dep namespace, bridge va tien trinh/artifact runtime cua lab 07.
# Chay: sudo bash cleanup.sh

# Dung cac daemon neu con chay
pkill -f 'named -g -c /var/cache/bind/lab07' 2>/dev/null
pkill -f 'unbound -d -c /etc/unbound/lab07' 2>/dev/null

for ns in auth resolver client attacker; do
  ip netns del "$ns" 2>/dev/null
done
ip link del br0 2>/dev/null

rm -rf /var/cache/bind/lab07 /etc/unbound/lab07 /run/unbound.pid 2>/dev/null
echo "[+] Da xoa namespace (auth, resolver, client, attacker), bridge br0"
echo "    va thu muc runtime (/var/cache/bind/lab07, /etc/unbound/lab07)."
