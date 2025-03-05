import time
import csv

INTERFACE = "cx5if0"
RX_FILE = f"/sys/class/net/{INTERFACE}/statistics/rx_packets"
OUTPUT_CSV = "rx_packets_per_second.csv"


def get_rx_packets():
    """Read the number of received packets from the interface statistics."""
    try:
        with open(RX_FILE, "r") as f:
            return int(f.read().strip())
    except Exception as e:
        print(f"Error reading RX packets: {e}")
        return None


def monitor_rx_packets(interval=1, duration=60):
    """Monitor RX packets per second and save to CSV."""
    with open(OUTPUT_CSV, "w", newline="") as csvfile:
        csv_writer = csv.writer(csvfile)
        csv_writer.writerow(["Timestamp", "Packets_per_second"])

        prev_packets = get_rx_packets()
        if prev_packets is None:
            return

        for _ in range(duration):
            time.sleep(interval)
            current_packets = get_rx_packets()
            if current_packets is None:
                continue

            pps = current_packets - prev_packets
            timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
            csv_writer.writerow([timestamp, pps])
            print(f"{timestamp} - Packets per second: {pps}")
            prev_packets = current_packets


if __name__ == "__main__":
    monitor_rx_packets(interval=1, duration=60)  # Run for 60 seconds
