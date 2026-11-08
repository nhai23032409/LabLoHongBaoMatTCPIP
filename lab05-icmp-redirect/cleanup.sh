#!/bin/bash
# cleanup.sh - Don dep toan bo namespace va bridge cua lab 05.
# Chay: sudo bash cleanup.sh
for ns in vic gw atk dst; do
  ip netns del "$ns" 2>/dev/null
done
ip link del br0 2>/dev/null
echo "[+] Da xoa cac namespace (vic, gw, atk, dst) va bridge br0."
