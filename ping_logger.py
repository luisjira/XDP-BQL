import subprocess
import sys
import re

def ping_host(host, output_file, count=1000):
    with open(output_file, "w") as file:
        for i in range(count):
            try:
                result = subprocess.run([
                    "ping", "-c", "1", "-4" if ":" not in host else "-6", host
                ], capture_output=True, text=True)

                match = re.search(r'time=([0-9.]+) ms', result.stdout)
                if match:
                    rtt = match.group(1)
                    file.write(f"{rtt}\n")
                    print(f"Ping {i+1}: {rtt} ms")
                else:
                    file.write("NaN\n")
                    print(f"Ping {i+1}: Request timed out")
            except Exception as e:
                print(f"Error: {e}")
                file.write("NaN\n")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python script.py <IP_ADDRESS> <OUTPUT_FILE>")
        sys.exit(1)

    host = sys.argv[1]
    output_file = sys.argv[2]
    ping_host(host, output_file)
