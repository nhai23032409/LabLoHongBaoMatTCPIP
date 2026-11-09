#!/bin/bash
# defense.sh - Bat PHONG THU tren nan nhan: BO QUA ICMP redirect roi xoa route cache.
# Sau buoc nay, gui lai redirect gia -> victim khong doi route.
# Chay: sudo bash defense.sh
for k in all vic0; do
  ip netns exec vic sysctl -w net.ipv4.conf.$k.accept_redirects=0
done
ip netns exec vic ip route flush cache
echo "[+] Victim DA BO QUA ICMP redirect; route toi 10.0.1.5 giu nguyen qua GW hop phap."
