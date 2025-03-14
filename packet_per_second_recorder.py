import argparse
import time
import csv

def get_rx_packets(interface):
    """Read the number of received packets from the interface statistics."""
    rx_file = f"/sys/class/net/{interface}/statistics/rx_packets"
    try:
        with open(rx_file, "r") as f:
            return int(f.read().strip())
    except Exception as e:
        print(f"Error reading RX packets: {e}")
        return None


def monitor_rx_packets(interface, out, interval=1, duration=10):
    """Monitor RX packets per second and save to CSV."""
    if out is None:
        out = f"pps_{interface}.csv"

    with open(out, "w", newline="") as csvfile:
        csv_writer = csv.writer(csvfile)
        csv_writer.writerow(["Timestamp", "Packets_per_second"])

        prev_packets = get_rx_packets(interface)
        if prev_packets is None:
            return

        total = 0

        for _ in range(duration):
            time.sleep(interval)
            current_packets = get_rx_packets(interface)
            if current_packets is None:
                continue

            pps = current_packets - prev_packets
            total += pps
            timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
            csv_writer.writerow([timestamp, pps])
            print(f"{timestamp} - Packets per second: {pps}")
            prev_packets = current_packets
        print(f"Average: {total/duration}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Show and save packets per second received on interface")
    parser.add_argument("interface", help="Interface to collect counter from")
    parser.add_argument("-i","--interval", type=float, default=1, help="Interval to collect data in in seconds")
    parser.add_argument("-t","--duration", type=int, default=10, help="Time to collect data for in seconds")
    parser.add_argument("-w","--output-file", help="Name of output file to write csv data to")

    args = parser.parse_args()

    monitor_rx_packets(args.interface, args.output_file, interval=args.interval, duration=args.duration)
