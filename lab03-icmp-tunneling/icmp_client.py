#!/usr/bin/env python3
"""Send a bounded, user-selected payload over ICMP in the isolated lab."""
import argparse
import sys
from pathlib import Path
from scapy.all import ICMP, IP, Raw, conf, sr1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--file", type=Path)
    source.add_argument("--text")
    parser.add_argument("--target", default="10.0.0.2")
    parser.add_argument("--chunk", type=int, default=24)
    parser.add_argument("--timeout", type=float, default=2.0)
    args = parser.parse_args()
    if args.chunk < 1 or args.chunk > 1200:
        parser.error("--chunk phải nằm trong khoảng 1..1200 bytes")
    data = args.file.read_bytes() if args.file else args.text.encode("utf-8")
    if not data:
        parser.error("payload không được rỗng")
    conf.verb = 0
    total = (len(data) + args.chunk - 1) // args.chunk
    failed = 0
    for seq, start in enumerate(range(0, len(data), args.chunk)):
        segment = data[start:start + args.chunk]
        answer = sr1(
            IP(dst=args.target) / ICMP(type=8, id=0x1337, seq=seq) / Raw(segment),
            iface="veth1", timeout=args.timeout, retry=0, verbose=False,
        )
        if not answer or not answer.haslayer(ICMP):
            print(f"[client] timeout seq={seq}", file=sys.stderr)
            failed += 1
            continue
        ack = bytes(answer[ICMP].payload)
        if not ack.startswith(b"ACK:") or ack[4:] != segment:
            print(f"[client] invalid ACK seq={seq}: {ack!r}", file=sys.stderr)
            failed += 1
            continue
        print(f"[client] ACK seq={seq}/{total - 1} bytes={len(segment)}")
    if failed:
        print(f"[client] failed chunks={failed}/{total}", file=sys.stderr)
        return 1
    print(f"[client] completed bytes={len(data)} chunks={total}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
