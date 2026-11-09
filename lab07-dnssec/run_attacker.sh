#!/bin/bash
# run_attacker.sh - Khoi chay BIND9 authoritative GIA MAO (rogue) tren may
# attacker (10.0.0.40), phuc vu secure.lab voi du lieu FORGED va KHONG ky DNSSEC.
# Mo phong ke tan cong chen giua (MITM) / dau doc cache. Chay o foreground.
#
# Thu muc /var/cache/bind/lab07/attacker nam trong vung AppArmor cho phep.
# Chay:  sudo ip netns exec attacker bash run_attacker.sh
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD=/var/cache/bind/lab07/attacker
CONF="$BUILD/named.conf"

mkdir -p "$BUILD"
cp "$HERE/zones/secure.lab.forged.zone" "$BUILD/secure.lab.forged.zone"

cat > "$CONF" <<EOF
options {
    directory "$BUILD";
    pid-file "$BUILD/named.pid";
    listen-on port 53 { 10.0.0.40; 127.0.0.1; };
    listen-on-v6 { none; };
    recursion no;
    dnssec-validation no;
    allow-query { any; };
};
zone "secure.lab" {
    type master;
    file "secure.lab.forged.zone";
};
EOF

echo "[+] attacker: named GIA MAO phuc vu secure.lab (forged, KHONG ky) tai 10.0.0.40:53"
exec named -g -c "$CONF"
