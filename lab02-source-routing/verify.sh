#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$ROOT"
if [[ ${EUID} -ne 0 ]]; then echo "[!] Chạy bằng root: sudo ./verify.sh" >&2; exit 1; fi
ip netns list | grep -q '^h1 ' || { echo "[!] Chạy setup_pair.sh trước." >&2; exit 1; }
printf '[1/4] Ping cơ bản... '
ip netns exec h1 ping -c 1 -W 1 10.0.0.2 >/dev/null
echo OK
printf '[2/4] Scapy... '
ip netns exec h1 python3 -c 'import scapy' >/dev/null
echo OK
printf '[3/4] Vulnerable state (h2 accept_source_route=1)...\n'
ip netns exec h2 sysctl -qw net.ipv4.conf.all.accept_source_route=1
ip netns exec h2 sysctl -qw net.ipv4.conf.veth2.accept_source_route=1
ip netns exec h1 python3 "$ROOT/source_route.py" --mode ssrr || echo "[!] Không thấy reply; kernel có thể vẫn chặn source routing."
printf '[4/4] Defensive state (h2 accept_source_route=0)...\n'
ip netns exec h2 sysctl -qw net.ipv4.conf.all.accept_source_route=0
ip netns exec h2 sysctl -qw net.ipv4.conf.veth2.accept_source_route=0
if ip netns exec h1 python3 "$ROOT/source_route.py" --mode ssrr; then
  echo "[!] Vẫn thấy reply sau khi bật phòng thủ." >&2; exit 1
fi
echo "[+] Không có reply sau khi tắt accept_source_route. Verification completed"
