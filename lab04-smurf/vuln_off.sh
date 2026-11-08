#!/bin/bash
# vuln_off.sh - BAT PHONG THU.
# Cac may amp1-3 BO QUA ICMP echo gui toi broadcast (=1, mac dinh Linux hien dai).
# Sau khi chay, tan cong Smurf khong con khuech dai duoc nua.
# Chay: sudo bash vuln_off.sh
for h in amp1 amp2 amp3; do
  ip netns exec "$h" sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1
done
echo "[+] amp1-3 DA BO QUA ping broadcast => da phong thu Smurf."
