#!/bin/bash
# run_auth.sh - Khoi chay BIND9 authoritative THAT tren may auth (10.0.0.10),
# phuc vu zone secure.lab DA KY DNSSEC. Chay o foreground (giu terminal nay).
#
# Thu muc runtime /var/cache/bind/lab07/auth nam trong vung AppArmor cho phep
# named doc/ghi, nen KHONG bi "permission denied".
#
# Yeu cau: da chay sign_zone.sh truoc (tao secure.lab.zone.signed).
# Chay:  sudo ip netns exec auth bash run_auth.sh
set -e

BUILD=/var/cache/bind/lab07/auth
CONF="$BUILD/named.conf"

if [ ! -f "$BUILD/secure.lab.zone.signed" ]; then
  echo "[x] Chua thay zone da ky. Hay chay 'sudo bash sign_zone.sh' truoc."
  exit 1
fi

cat > "$CONF" <<EOF
options {
    directory "$BUILD";
    pid-file "$BUILD/named.pid";
    listen-on port 53 { 10.0.0.10; 127.0.0.1; };
    listen-on-v6 { none; };
    recursion no;
    dnssec-validation no;
    allow-query { any; };
};
zone "secure.lab" {
    type master;
    file "secure.lab.zone.signed";
};
EOF

echo "[+] auth: named phuc vu secure.lab (da ky) tai 10.0.0.10:53 (Ctrl+C de dung)"
exec named -g -c "$CONF"
