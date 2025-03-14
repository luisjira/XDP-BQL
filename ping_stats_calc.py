import sys
import statistics

PING_CNT = 1000

def process_csv(file_path):
    try:
        with open(file_path, "r") as file:
            values = [float(line.strip()) for line in file if line.strip()]

            if not values:
                print("No valid numerical data found in the file.")
                return

            print(f"median={statistics.median(values)},")
            print(f"average={statistics.mean(values)},")
            print(f"lower whisker={min(values)},")
            print(f"upper whisker={max(values)}")
            print("===========")
            print(f"packet loss={1.0 - len(values)/PING_CNT}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <csv_file>")
        sys.exit(1)

    process_csv(sys.argv[1])
