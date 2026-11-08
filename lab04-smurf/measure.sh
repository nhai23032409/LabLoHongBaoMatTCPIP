#!/bin/bash
# measure.sh - Do he so khuech dai tai nan nhan.
# Bat tcpdump o nan nhan (chi dem echo-REPLY doi ve), roi phat N goi tu attacker,
# cuoi cung in ra so goi gui / so reply nhan / he so khuech dai.
#
# Chay o terminal thuong (root namespace), can root:
#   sudo bash measure.sh [SO_GIAY] [SO_GOI]
#   sudo bash measure.sh            # mac dinh 5 giay, 10 goi
set -e
SECS=${1:-5}
COUNT=${2:-10}
DIR="$(cd "$(dirname "$0")" && pwd)"
TMP="/tmp/smurf_count.txt"

echo "[i] Bat tcpdump tai nan nhan (vic) trong ${SECS}s, chi dem echo-reply..."
ip netns exec vic timeout "${SECS}" \
  tcpdump -i vic0 -nn 'icmp[icmptype]==icmp-echoreply' 2>/dev/null > "${TMP}" &
TPID=$!

sleep 1
echo "[i] Attacker phat ${COUNT} goi ICMP echo toi broadcast (nguon = nan nhan)..."
ip netns exec atk python3 "${DIR}/smurf.py" --count "${COUNT}" >/dev/null

wait "${TPID}" 2>/dev/null || true
REPLIES=$(wc -l < "${TMP}")

echo "---------------------------------------------"
echo "  Goi gui di (requests)    : ${COUNT}"
echo "  Echo-reply doi ve victim : ${REPLIES}"
if [ "${COUNT}" -gt 0 ]; then
  echo "  He so khuech dai (~)     : $((REPLIES / COUNT))x  (ky vong = so may amp dang bat)"
fi
echo "---------------------------------------------"
rm -f "${TMP}"
