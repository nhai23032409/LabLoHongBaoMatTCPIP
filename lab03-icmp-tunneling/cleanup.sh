#!/usr/bin/env bash
set -Eeuo pipefail
if [[ ${EUID} -ne 0 ]]; then echo "[!] Chạy bằng root: sudo bash ./cleanup.sh" >&2; exit 1; fi
ip netns exec h2 iptables -D INPUT -p tcp -j DROP 2>/dev/null || true
ip netns del h1 2>/dev/null || true
ip netns del h2 2>/dev/null || true
echo "[+] Đã xóa h1 và h2"
