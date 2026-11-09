#!/bin/bash
# mitm_forward.sh - (TUY CHON) Bien attacker thanh MITM THUC SU co chuyen tiep goi.
# Nho vay nan nhan VAN truy cap duoc dst (khong mat ket noi) trong khi moi goi
# van di xuyen qua attacker (attacker "nghe" duoc luu luong).
#
# Neu KHONG chay buoc nay: sau tan cong, goi cua victim toi atk se bi rot
# (attacker chi thay bang tcpdump chu khong chuyen tiep) -> victim mat ket noi toi dst.
#
# Chay: sudo bash mitm_forward.sh
set -e

# Bat chuyen tiep goi tren attacker
ip netns exec atk sysctl -w net.ipv4.ip_forward=1

# TAT send_redirects tren attacker: neu khong, attacker (dong vai router) se gui
# mot redirect HOP LE bao victim di thang qua GW -> pha hong don tan cong.
ip netns exec atk sysctl -w net.ipv4.conf.all.send_redirects=0
ip netns exec atk sysctl -w net.ipv4.conf.atk0.send_redirects=0

# Attacker can biet duong toi mang 10.0.1.0/24 -> di qua GW hop phap
ip netns exec atk ip route add 10.0.1.0/24 via 10.0.0.1 2>/dev/null || true

echo "[+] Attacker da san sang chuyen tiep: victim -> atk -> gw -> dst (MITM thuc su)."
