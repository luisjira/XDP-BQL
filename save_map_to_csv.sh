#!/bin/bash

# Output CSV file
CSV_FILE="port_state_map_output.csv"

# Function to parse and write map content to CSV
function save_map_to_csv {
    # Ensure the output CSV file exists and has a header
    if [ ! -f "$CSV_FILE" ]; then
        echo "Timestamp, Key, tx_port_idx, returned, num_queued, adj_limit, last_obj_cnt, limit, num_completed, prev_ovlimit, prev_num_queued, prev_last_obj_cnt, lowest_slack, slack_start_time, max_limit, min_limit, slack_hold_time" > "$CSV_FILE"
    fi

    # Read the map content from the pinned file
    local timestamp=$(date +%s)
    while read -r line; do
        # Skip warning lines or empty lines
        if [[ "$line" =~ ^# ]] || [[ -z "$line" ]]; then
            continue
        fi

        # Parse the key and value
        key=$(echo "$line" | cut -d: -f1 | tr -d ' ')
        value=$(echo "$line" | cut -d: -f2 | tr -d '{}' | tr -d ' ')

        # Append the data to the CSV file
        echo "$timestamp,$key,$value" >> "$CSV_FILE"
    done < <(cat /sys/fs/bpf/dst_port_state)
    echo "$timestamp written"
}

# Main loop to continuously save the map content to CSV
start=$(date +%s)
echo $start
echo $(($start + $1))
while [ $(date +%s) -le $(($start + $1)) ]; do
    save_map_to_csv
    sleep 0.01
done
