#!/bin/bash
# health_check.sh - Thong ke tai-rap manh IP cua victim (h2).
# Chay TRUOC va SAU tan cong de so sanh ReasmFails / ReasmOKs / ReasmReqds.
# Chay: sudo bash health_check.sh
echo "== /proc/net/snmp (dong Ip:) cua victim h2 =="
ip netns exec h2 sh -c "cat /proc/net/snmp | grep -A1 '^Ip:'"
echo
echo "== Trich rieng cac bo dem tai-rap =="
ip netns exec h2 sh -c '
hdr=$(grep "^Ip:" /proc/net/snmp | head -1)
val=$(grep "^Ip:" /proc/net/snmp | tail -1)
i=1
for name in $hdr; do
  case "$name" in
    ReasmReqds|ReasmOKs|ReasmFails)
      col=$(echo "$val" | cut -d" " -f"$i")
      printf "  %-11s = %s\n" "$name" "$col" ;;
  esac
  i=$((i+1))
done'
