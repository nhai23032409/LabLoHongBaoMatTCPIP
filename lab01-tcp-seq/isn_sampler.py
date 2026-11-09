#!/usr/bin/env python3
# isn_sampler.py - Lay mau Initial Sequence Number (ISN) cua may chu de DANH GIA
# muc do DOAN TRUOC DUOC cua ISN. Day la buoc trinh sat trong tan cong
# "TCP Sequence Number Prediction": neu ISN tang theo quy luat -> ke tan cong
# off-path co the DOAN so thu tu ke tiep va chen goi gia mao.
#
# Cach lam: gui nhieu goi SYN toi 1 cong DANG MO cua victim, bat SYN-ACK va ghi
# lai ISN (truong seq cua server). Tinh do lech giua cac ISN lien tiep.
#   - Kernel CU (predictable): delta ~ hang so nho (vd +1, +64000/s, +128000) => DE DOAN.
#   - Kernel HIEN DAI (RFC 6528): ISN = bam mat ma theo 4-tuple + dong ho => delta NGAU NHIEN.
#
# LAB-ONLY - chi chay trong namespace co lap.
# Chay trong namespace attacker (can root):
#   # Tren victim h2, mo 1 cong lang nghe truoc, vd:  ip netns exec h2 nc -lk 8080
#   sudo ip netns exec h1 python3 isn_sampler.py --dst 10.0.0.2 --dport 8080 -n 30
#
import argparse
import statistics
from scapy.all import IP, TCP, sr1, RandShort, conf

conf.verb = 0


def sample_isn(dst, dport, count, timeout):
    isns = []
    for i in range(count):
        sport = int(RandShort())
        pkt = IP(dst=dst) / TCP(sport=sport, dport=dport, flags="S", seq=1000 + i)
        ans = sr1(pkt, timeout=timeout)
        if ans is not None and ans.haslayer(TCP) and (ans[TCP].flags & 0x12) == 0x12:
            # 0x12 = SYN+ACK -> cong mo, server da chon ISN
            isns.append(ans[TCP].seq)
            # Gui RST de dong nua ket noi, giu victim sach se
            rst = IP(dst=dst) / TCP(sport=sport, dport=dport, flags="R",
                                    seq=ans[TCP].ack)
            sr1(rst, timeout=0.2)
        else:
            print(f"[!] Mau {i}: khong nhan duoc SYN-ACK (cong dong? bi loc?). Bo qua.")
    return isns


def analyze(isns):
    if len(isns) < 2:
        print("[x] Khong du mau de phan tich. Hay chac chan cong dang MO tren victim.")
        return
    deltas = [(isns[i + 1] - isns[i]) & 0xFFFFFFFF for i in range(len(isns) - 1)]
    print("\n== ISN thu thap duoc ==")
    for k, s in enumerate(isns):
        print(f"  #{k:02d}  ISN = {s:>10}  (0x{s:08x})")
    print("\n== Do lech giua cac ISN lien tiep (delta, mod 2^32) ==")
    print("  ", deltas)
    rng = max(deltas) - min(deltas)
    mean = statistics.mean(deltas)
    stdev = statistics.pstdev(deltas)
    print(f"\n  So mau       : {len(isns)}")
    print(f"  delta min    : {min(deltas)}")
    print(f"  delta max    : {max(deltas)}")
    print(f"  delta trung binh: {mean:.1f}")
    print(f"  do lech chuan   : {stdev:.1f}")
    print(f"  bien do (max-min): {rng}")

    # Hon 2^31 bien do coi nhu trai khap khong gian 32-bit -> ngau nhien
    if rng > (1 << 28):
        print("\n[KET LUAN] ISN trai rong tren khong gian 32-bit -> NGAU NHIEN hoa.")
        print("           Kernel hien dai (RFC 6528). Tan cong doan ISN off-path"
              " la BAT KHA THI (phai do ~2^32 kha nang).")
    else:
        print("\n[KET LUAN] Delta nho/on dinh -> ISN DOAN TRUOC DUOC (he cu).")
        print("           Ke tan cong off-path co the suy ra ISN ke tiep va spoofing.")


def main():
    ap = argparse.ArgumentParser(description="Lay mau & danh gia ISN (lab-only)")
    ap.add_argument("--dst", default="10.0.0.2", help="IP victim/server")
    ap.add_argument("--dport", type=int, default=8080, help="Cong DANG MO tren victim")
    ap.add_argument("-n", "--count", type=int, default=30, help="So mau ISN")
    ap.add_argument("--timeout", type=float, default=1.0, help="Timeout cho moi SYN")
    args = ap.parse_args()

    print(f"[*] Lay {args.count} mau ISN tu {args.dst}:{args.dport} ...")
    isns = sample_isn(args.dst, args.dport, args.count, args.timeout)
    analyze(isns)


if __name__ == "__main__":
    main()
