#!/bin/bash
# demo.sh - Cac truy van kiem chung tu may client (10.0.0.30) toi resolver.
# Chay:  sudo ip netns exec client bash demo.sh
R=10.0.0.20   # resolver

echo "=================================================================="
echo " 1) Truy van co xac thuc DNSSEC (mong doi: co co 'ad', status NOERROR)"
echo "=================================================================="
dig @$R bank.secure.lab A +dnssec +multiline | sed -n '1,25p'

echo
echo "=================================================================="
echo " 2) Xem cac ban ghi RRSIG / DNSKEY (bang chung zone da duoc ky)"
echo "=================================================================="
dig @$R secure.lab DNSKEY +dnssec +short
dig @$R bank.secure.lab RRSIG +short

echo
echo "=================================================================="
echo " 3) delv - cong cu xac thuc chi tiet (mong doi: 'fully validated')"
echo "=================================================================="
dig @$R bank.secure.lab A +cd >/dev/null 2>&1   # (lam am; delv tu truy van)
delv @$R +root=secure.lab bank.secure.lab A 2>/dev/null || \
  echo "(delv co the can trust anchor rieng; tham khao README muc 4)"

echo
echo "Ghi chu:"
echo "  - Co 'ad' (Authenticated Data) = resolver DA XAC THUC chuoi chu ky toi trust anchor."
echo "  - Neu dang tro resolver sang attacker (10.0.0.40) va zone gia KHONG ky,"
echo "    truy van (2) se tra 'status: SERVFAIL' => DNSSEC da CHAN du lieu gia mao."
