#!/bin/bash
# cleanup.sh - Xoa namespace cua lab 01 (veth tu dong mat theo namespace).
# Chay: sudo bash cleanup.sh
for ns in h1 h2; do
  ip netns del "$ns" 2>/dev/null
done
echo "[+] Da xoa namespace h1, h2."
