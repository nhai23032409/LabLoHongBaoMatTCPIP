#!/bin/bash
# check_route.sh - Xem duong di hien tai cua victim toi dst (kiem chung truoc/sau tan cong).
# Chay: sudo bash check_route.sh [DST]   (mac dinh DST=10.0.1.5)
DST=${1:-10.0.1.5}
echo "== ip route get ${DST} (cua victim) =="
ip netns exec vic ip route get "${DST}"
echo
echo "== ip route show cache (co the RONG tren kernel moi - khong sao) =="
ip netns exec vic ip route show cache
