#!/bin/bash
# sign_zone.sh - Sinh khoa DNSSEC (KSK+ZSK), KY zone secure.lab, va XUAT:
#   - secure.lab.zone.signed : zone da ky (named se phuc vu)
#   - trust-anchor.conf       : dong 'trust-anchor:' cho unbound (resolver)
#   - ds.txt                  : ban ghi DS (de ky thac tu zone cha trong thuc te)
#
# Thu muc runtime dat trong vung AppArmor CHO PHEP:
#   - named  doc/ghi: /var/cache/bind/**   -> AUTH=/var/cache/bind/lab07/auth
#   - unbound chi doc: /etc/unbound/**     -> RES =/etc/unbound/lab07
#
# Chay tren may auth (hoac root netns deu duoc - chi la thao tac crypto cuc bo):
#   sudo bash sign_zone.sh
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
AUTH=/var/cache/bind/lab07/auth
RES=/etc/unbound/lab07
ZONE=secure.lab

mkdir -p "$AUTH" "$RES"
cd "$AUTH"
cp "$HERE/zones/${ZONE}.zone" "./${ZONE}.zone"

echo "[*] Sinh khoa ZSK va KSK (ECDSAP256SHA256) ..."
rm -f K${ZONE}.*+*.key K${ZONE}.*+*.private 2>/dev/null || true
ZSK=$(dnssec-keygen -a ECDSAP256SHA256 -n ZONE "$ZONE")
KSK=$(dnssec-keygen -a ECDSAP256SHA256 -f KSK -n ZONE "$ZONE")
echo "    ZSK = $ZSK"
echo "    KSK = $KSK"

# Nhung DNSKEY vao zone roi ky
cat "${ZSK}.key" "${KSK}.key" >> "${ZONE}.zone"

echo "[*] Ky zone (khoa da nhung vao zone o tren) ..."
dnssec-signzone -o "$ZONE" -N INCREMENT -t "${ZONE}.zone"
# Ket qua: ${ZONE}.zone.signed , dsset-${ZONE}. , va cac RRSIG/NSEC ben trong

echo "[*] Xuat trust anchor (KSK DNSKEY) cho unbound ..."
# Lay ban ghi DNSKEY cua KSK tu file khoa; bo class/TTL, giu tu 'DNSKEY ...' tro di
KEYRR=$(grep -v '^;' "${KSK}.key" | grep -i 'DNSKEY' | head -1)
RR=$(echo "$KEYRR" | sed -E 's/.*DNSKEY/DNSKEY/')
# Ghi trust anchor vao CA vung unbound doc duoc (RES) va ban sao o AUTH
echo "trust-anchor: \"secure.lab. ${RR}\"" | tee "$RES/trust-anchor.conf" > "$AUTH/trust-anchor.conf"

# DS record (de minh hoa chuoi tin cay: trong thuc te nop cho zone cha .lab)
cp "dsset-${ZONE}." ds.txt 2>/dev/null || dnssec-dsfromkey "${KSK}.key" > ds.txt

echo
echo "[+] Hoan tat."
echo "    - $AUTH/${ZONE}.zone.signed  (named phuc vu)"
echo "    - $RES/trust-anchor.conf     (unbound dung lam diem tin cay)"
echo "    - $AUTH/ds.txt               (ban ghi DS)"
echo
echo "== DS record (secure.lab) =="
cat ds.txt
