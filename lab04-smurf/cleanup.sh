#!/bin/bash
# cleanup.sh - Don dep toan bo namespace va bridge cua lab 04.
# Chay: sudo bash cleanup.sh
for ns in atk vic amp1 amp2 amp3; do
  ip netns del "$ns" 2>/dev/null
done
ip link del br0 2>/dev/null
echo "[+] Da xoa cac namespace (atk, vic, amp1-3) va bridge br0."
