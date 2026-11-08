#!/bin/bash
# vuln_on.sh - TAI TAO DIEM YEU.
# Cho cac may khuech dai (amp1-3) tra loi ICMP echo gui toi dia chi broadcast.
# Day la hanh vi cua he thong cu; Linux hien dai MAC DINH da tat (=1).
# Chay: sudo bash vuln_on.sh
for h in amp1 amp2 amp3; do
  ip netns exec "$h" sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=0
done
echo "[!] amp1-3 DA BAT tra loi ping broadcast => LAN de bi Smurf."
