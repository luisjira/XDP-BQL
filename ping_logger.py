import subprocess
import sys
import re

def ping_host(host, output_file, count=1000, interval=0.01):
    try:
        # Determine IPv4 or IPv6 and construct the ping command
        command = ["ping", "-i", str(interval), "-c", str(count), host]

        # Execute the ping command
        result = subprocess.run(command, capture_output=True, text=True)

        # Extract RTT values from output
        rtt_values = re.findall(r'time=([0-9.]+) ms', result.stdout)

        # Extract packet loss percentage
        loss_match = re.search(r'([0-9.]+)% packet loss', result.stdout)
        packet_loss = loss_match.group(1) if loss_match else "Unknown"

        # Write RTT values to output file
        with open(output_file, "w") as file:
            for rtt in rtt_values:
                file.write(f"{rtt}\n")

        print(f"Collected {len(rtt_values)} RTT values.")
        print(f"Packet loss: {packet_loss}%")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python script.py <IP_ADDRESS> <OUTPUT_FILE>")
        sys.exit(1)

    host = sys.argv[1]
    output_file = sys.argv[2]
    ping_host(host, output_file)
