#!/usr/bin/env python3
"""Send a source-routed ICMP probe in the isolated Lab 02 topology."""
import argparse
import sys
import time
from scapy.all import AsyncSniffer, ICMP, IP, IPOption_LSRR, IPOption_SSRR, Raw, conf, send

H1 = "10.0.0.1"
H2 = "10.0.0.2"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("ssrr", "lsrr"), default="ssrr")
    parser.add_argument("--spoof", default="10.0.0.77")
    parser.add_argument("--timeout", type=float, default=2.0)
    args = parser.parse_args()
    conf.verb = 0
    option_cls = IPOption_SSRR if args.mode == "ssrr" else IPOption_LSRR
    route = [H1, H2]
    packet = IP(src=args.spoof, dst=H2, options=[option_cls(routers=route)]) / ICMP(id=0x4242, seq=1) / Raw(b"lab02-source-routing")
    sniffer = AsyncSniffer(
        iface="veth1", filter="icmp", store=True,
        lfilter=lambda p: p.haslayer(IP) and p[IP].src == H2 and p[IP].dst == H1,
    )
    sniffer.start()
    try:
        print(f"[*] Sending {args.mode.upper()} probe: src={args.spoof}, dst={H2}, route={route}")
        send(packet, iface="veth1", verbose=False)
        time.sleep(args.timeout)
    finally:
        # join(timeout=...) only waits; it does not stop AsyncSniffer.
        # Stop explicitly so results is finalized and the process cannot hang.
        if getattr(sniffer, "running", False):
            sniffer.stop(join=True)
    replies = sniffer.results or []
    if replies:
        print(f"[+] Received {len(replies)} reversed-route ICMP reply packet(s) on h1")
        return 0
    print("[-] No reversed-route reply observed", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
