#!/bin/bash
# run_resolver.sh - Khoi chay unbound (resolver XAC THUC DNSSEC) tren may
# resolver (10.0.0.20). Dung trust anchor cua secure.lab (do sign_zone.sh xuat)
# va chuyen (stub) truy van secure.lab toi UPSTREAM.
#
#   UPSTREAM=10.0.0.10 (mac dinh) -> may auth THAT  => tra loi hop le, co co AD
#   UPSTREAM=10.0.0.40            -> may attacker GIA => chu ky sai => SERVFAIL
#
# Config + trust anchor dat trong /etc/unbound/lab07 (vung unbound DOC duoc theo
# AppArmor); pidfile dat o /run/unbound.pid (vung duoc phep ghi).
#
# Chay o foreground (giu terminal nay).
# Chay:  sudo ip netns exec resolver bash run_resolver.sh
#        sudo ip netns exec resolver env UPSTREAM=10.0.0.40 bash run_resolver.sh
set -e

RES=/etc/unbound/lab07
TA="$RES/trust-anchor.conf"
UPSTREAM="${UPSTREAM:-10.0.0.10}"

if [ ! -f "$TA" ]; then
  echo "[x] Chua thay trust anchor ($TA). Hay chay 'sudo bash sign_zone.sh' truoc."
  exit 1
fi

mkdir -p "$RES"
CONF="$RES/unbound.conf"

cat > "$CONF" <<EOF
server:
    directory: "$RES"
    pidfile: "/run/unbound.pid"
    chroot: ""
    username: ""
    interface: 10.0.0.20
    interface: 127.0.0.1
    port: 53
    do-ip6: no
    access-control: 10.0.0.0/24 allow
    access-control: 127.0.0.0/8 allow
    module-config: "validator iterator"
    val-permissive-mode: no
    harden-dnssec-stripped: yes
    verbosity: 2
    logfile: ""
    use-syslog: no
    include: "$TA"

stub-zone:
    name: "secure.lab"
    stub-addr: $UPSTREAM
    stub-prime: no
EOF

echo "[+] resolver: unbound (validating) tai 10.0.0.20:53, upstream secure.lab = $UPSTREAM"
echo "    Trust anchor: $TA"
exec unbound -d -c "$CONF"
