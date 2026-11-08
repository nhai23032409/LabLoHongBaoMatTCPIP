#!/usr/bin/env bash
set -Eeuo pipefail
if [[ ${EUID} -ne 0 ]]; then echo "[!] Chạy bằng root: sudo ./cleanup.sh" >&2; exit 1; fi
ip netns del h1 2>/dev/null || true
ip netns del h2 2>/dev/null || true
echo "[+] Đã xóa h1 và h2"
