#!/usr/bin/env bash
set -x

### GENERAL SETUP ###
FWDS=('kernel' 'xdp' 'xdp-icmp' 'xdp-q' 'xdp-q-icmp' 'xdp-bql' 'xdp-bql-icmp')
XDP_HOST=nslrackvm  # Remote forwarding host, assumed to have this dir in ~
SSH_CMD='ssh -F ~/.ssh/config -i ~/.ssh/id_rsa -o UserKnownHostsFile=~/.ssh/known_hosts'
PYENV_PATH='~/myenv/bin/' # env must have argparse installed
XDP_TX_IF=ens16f1np1
XDP_RX_IF=ens16f0np0
NS_TX_IF=cx5if1
NS_RX_IF=cx5if0

### TRAFFIC GENERATION ###
LOADED=true         # Generate network load
D_PORT=1000         # dynamic port range for xdp-trafficgen
TRAFFIC_THREADS=1   # Threads for xdp-trafficgen
PACKET_SIZE=64      # UDP packet size for xdp-trafficgen

### LINK SPEEDS ###
LINK_SPEED_RX=1000  # link speed on rx subnet
LINK_SPEED_TX=10000 # link speed on tx subnet
LINK_MAX=100000     # max link speed

test_conn_v6()
{
    ip netns exec ns_tx ping -i 0.01 -c 100 -6  fd00:0:0:1::4 > /dev/null 2>&1
    return $?
}

test_conn_v4()
{
    ip netns exec ns_tx ping -i 0.01 -c 100 -4  169.254.1.4 > /dev/null 2>&1
    return $?
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --unloaded)
            LOADED=false
            shift
            ;;

        -d) 
            if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                D_PORT=$2
                shift 2
            else
                echo "Error: -d requires an integer argument."
                exit 1
            fi
            ;;

        -t)
            if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                TRAFFIC_THREADS=$2
                shift 2
            else
                echo "Error: -t requires an integer argument."
                exit 1
            fi
            ;;

        -rx) 
            if [[ -n "$2" && "$2" =~ ^[0-9]+$ && "$2" <= $LINK_MAX ]]; then
                LINK_SPEED_RX=$2
                shift 2
            else
                echo "Error: -rx requires an integer argument <= $LINK_MAX."
                exit 1
            fi
            ;;

        -tx)
            if [[ -n "$2" && "$2" =~ ^[0-9]+$ && "$2" <= $LINK_MAX ]]; then
                LINK_SPEED_TX=$2
                shift 2
            else
                echo "Error: -tx requires an integer argument <= $LINK_MAX."
                exit 1
            fi
            ;;

        --no-limit)
            LINK_SPEED_RX=$LINK_MAX
            LINK_SPEED_TX=$LINK_MAX
            shift
            ;;

        --fwd)
            if [[ -n "$2" && "${FWDS[@]}" =~ "${2}" ]]; then
                FWDS=($2)
                shift 2
            else
                echo "Error: --fwd requires a valid forwarding scheme."
                echo "Allowed are: ${FWDS[@]}"
                exit 1
            fi
            ;;

        --large-packets)
            PACKET_SIZE=1500
            shift
            ;;

        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Set link speed
$SSH_CMD $XDP_HOST "sudo ethtool -s ens16f1np1 speed $LINK_SPEED_TX"
$SSH_CMD $XDP_HOST "sudo ethtool -s ens16f0np0 speed $LINK_SPEED_RX"
LINK_SPEED_RX="$(( ${LINK_SPEED_RX} / 1000 ))G"

ip netns exec ns_tx ping -i 0.01 -c 10 -6  fd00::2 > /dev/null 2>&1
if $?; then
    echo "ns_tx cannot reach $XDP_HOST"
fi

ip netns exec ns_rx ping -i 0.01 -c 10 -6  fd00:0:0:1::3 > /dev/null 2>&1
if $?; then
    echo "ns_rx cannot reach $XDP_HOST"
fi

if $LOADED; then
    LOADED=loaded
    sudo -E ip netns exec ns_tx ./xdp-trafficgen udp \
        -A fd00::1 -m 1c:34:da:54:9a:a4 \
        -a fd00:0:0:1::4 \
        -p 12345 \
        -d $PACKET_SIZE \
        -t $TRAFFIC_THREADS \
        $NS_TX_IF
else
    LOADED=unloaded
fi

source $PYENV_PATH/activate

SUMMARY=" "
# Load forwarding schemes and run test loaded/unloaded
for fwd in "${FWDS[@]}"
do
    echo "Starting $fwd"
    $SSH_CMD $XDP_HOST "sudo -E ~/XDP-BQL/fwd-loader.sh ${fwd}"
    if test_conn_v6 && test_conn_v4; then
        SUMMARY="$SUMMARY | $fwd is reachable"
    else
        SUMMARY="$SUMMARY | $fwd is unreachable"
        continue
    fi
    sudo -E ip netns exec ns_rx ${PYENV_PATH}/python3 ./packet_per_second_recorder.py \
        $NS_RX_IF -w pps_${fwd}_${D_PORT}${LOADED}${PACKET_SIZE}B_link${LINK_SPEED_RX}.out
    
    sudo -E ip netns exec ns_tx ${PYENV_PATH}/python3 ./ping_logger.py fd00:0:0:1::4 \
        ping-${PACKET_SIZE}B-${LINK_SPEED_RX}-${D_PORT}${LOADED}-${fwd}.dat
done
echo "$SUMMARY"

