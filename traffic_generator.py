import argparse, netns, time
from scapy.all import sendp, IPv6, UDP, Raw, Ether, RandString

def generate_udp_packets(num_packets, payload_size, destination="fd00:0:0:1::4", port=12345):
    """Generates and sends UDP packets to the specified destination."""
    start_time = time.time()

    if payload_size:
         s = RandString(size=payload_size)
         for i in range(num_packets):
            packet = IPv6(dst=destination) / UDP(dport=port, sport=port) / Raw(load=s)
            sendp(packet, iface="cx5if1", verbose=False)
    else:
        for i in range(num_packets):
            packet = IPv6(dst=destination) / UDP(dport=port, sport=port) / Raw(load="Test Packet "+str(i)+"\n")
            sendp(packet, iface="cx5if1", verbose=False)

    print(f"Sent {num_packets} UDP packets to {destination}:{port} in {time.time()-start_time}s")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate UDP packets using Scapy.")
    parser.add_argument("destination", help="Destination IPv6 address")
    parser.add_argument("num_packets", type=int, help="Number of packets to send")
    parser.add_argument("--payload-size", type=int, help="Size of payload to send")

    args = parser.parse_args()

    generate_udp_packets(args.num_packets,payload_size=args.payload_size, destination=args.destination)
