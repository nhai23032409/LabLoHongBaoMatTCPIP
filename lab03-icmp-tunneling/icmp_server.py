#!/usr/bin/env python3
"""Receive a small ICMP payload channel inside the isolated lab namespace."""
import argparse
from scapy.all import ICMP, IP, Raw, conf, send, sniff


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--iface", default="veth2")
    parser.add_argument("--count", type=int, default=0, help="stop after N requests; 0 means forever")
    args = parser.parse_args()
    conf.verb = 0
    received = 0

    def handle(packet):
        nonlocal received
        if not packet.haslayer(IP) or not packet.haslayer(ICMP):
            return
        if packet[ICMP].type != 8:
            return
        data = bytes(packet[ICMP].payload)
        received += 1
        print(f"[server] seq={packet[ICMP].seq} bytes={len(data)} data={data!r}", flush=True)
        reply = IP(src=packet[IP].dst, dst=packet[IP].src) / ICMP(
            type=0, id=packet[ICMP].id, seq=packet[ICMP].seq
        ) / Raw(b"ACK:" + data)
        send(reply, iface=args.iface, verbose=False)

    print(f"[server] listening on {args.iface}", flush=True)
    sniff(
        iface=args.iface,
        filter="icmp",
        prn=handle,
        store=False,
        stop_filter=lambda _: args.count > 0 and received >= args.count,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
