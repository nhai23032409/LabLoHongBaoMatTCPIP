#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$ROOT"
if [[ ${EUID} -ne 0 ]]; then echo "[!] Chạy bằng root: sudo bash ./verify.sh" >&2; exit 1; fi
ip netns list | grep -q '^h1 ' || { echo "[!] Chạy setup_pair.sh trước." >&2; exit 1; }
ip netns exec h1 python3 -c 'import scapy' >/dev/null
ip netns exec h2 python3 -c 'import scapy' >/dev/null
server_log=$(mktemp)
server_pid=''
cleanup_verify() {
  if [[ -n "$server_pid" ]]; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi
  ip netns exec h2 iptables -D INPUT -p tcp -j DROP 2>/dev/null || true
  rm -f "$server_log"
}
trap cleanup_verify EXIT
ip netns exec h2 python3 "$ROOT/icmp_server.py" --count 5 >"$server_log" 2>&1 &
server_pid=$!
sleep 1
printf '[1/3] Gửi ICMP tunnel và kiểm tra ACK...\n'
ip netns exec h1 python3 "$ROOT/icmp_client.py" --text 'lab03-secret-payload' --chunk 8
printf '[2/3] Chặn TCP trên h2 nhưng giữ ICMP...\n'
ip netns exec h2 iptables -A INPUT -p tcp -j DROP
ip netns exec h1 python3 "$ROOT/icmp_client.py" --text 'icmp-still-works' --chunk 8
printf '[3/3] Xác nhận server đã nhận payload...\n'
grep -q 'lab03-secret-payload' "$server_log"
grep -q 'icmp-still-works' "$server_log"
echo '[+] Verification completed: ICMP works while TCP INPUT is dropped.'
