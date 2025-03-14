#!/usr/bin/env bash
set -x

### GENERAL SETUP ###
FWDS=('kernel' 'xdp' 'xdp-icmp' 'xdp-q' 'xdp-q-icmp' 'xdp-bql' 'xdp-bql-icmp')
XDP_HOST=nslrackvm  # Remote forwarding host, assumed to have this dir in ~
SSH_CONF_PATH='/home/ljira/.ssh'
SSH_CMD="ssh -F ${SSH_CONF_PATH}/config -i ${SSH_CONF_PATH}/id_rsa -o UserKnownHostsFile=${SSH_CONF_PATH}/known_hosts"
PYENV_PATH='/home/ljira/myenv/bin' # env must have argparse installed
XDP_TX_IF=ens16f0np0
XDP_RX_IF=ens16f1np1
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

# Test if netns $1 can ping host $2
# At least 1 from 100 pings has to complete
test_conn()
{
    ip netns exec $1 ping -i 0.01 -c 100  $2 > /dev/null 2>&1
    return $?
}

start_trafficgen()
{
    if $LOADED; then
       LOADED=loaded
       ip netns exec ns_tx ~/xdp-tools/xdp-trafficgen/xdp-trafficgen udp \
          -A fd00::1 \
          -m 1c:34:da:54:9a:a4 \
          -a fd00:0:0:1::4 \
          -p 12345 \
          -d $PACKET_SIZE \
          -t $TRAFFIC_THREADS \
          $NS_TX_IF > /dev/null &
       trafficgen_pid=$!
       sleep 5 # Wait for traffic
   else
      LOADED=unloaded
   fi
}

kill_trafficgen()
{
    kill $trafficgen_pid
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
            if [[ -n "$2" && "$2" =~ ^[0-9]+$ && "$2" -le $LINK_MAX ]]; then
                LINK_SPEED_RX=$2
                shift 2
            else
                echo "Error: -rx requires an integer argument <= $LINK_MAX."
                exit 1
            fi
            ;;

        -tx)
            if [[ -n "$2" && "$2" =~ ^[0-9]+$ && "$2" -le $LINK_MAX ]]; then
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
$SSH_CMD $XDP_HOST "sudo ethtool -s $XDP_TX_IF speed $LINK_SPEED_TX"
$SSH_CMD $XDP_HOST "sudo ethtool -s $XDP_RX_IF speed $LINK_SPEED_RX"
LINK_SPEED_RX="$(( ${LINK_SPEED_RX} / 1000 ))G"
sleep 10 # Give time for autonegotiation

if test_conn ns_tx fd00::2; then
    echo "ns_tx reached $XDP_HOST"
else
    echo "ns_tx cannot reach $XDP_HOST"
    exit 1
fi

if test_conn ns_rx fd00:0:0:1::3; then
    echo "ns_rx reached $XDP_HOST"
else
    echo "ns_rx cannot reach $XDP_HOST"
    exit 1
fi

source $PYENV_PATH/activate > /dev/null 2>&1

SUMMARY=" "
# Load forwarding schemes and run test loaded/unloaded
for fwd in "${FWDS[@]}"
do
    echo "Starting $fwd"
    $SSH_CMD $XDP_HOST "sudo -E ~/XDP-BQL/fwd-loader.sh ${fwd}"
    if test_conn ns_tx fd00:0:0:1::4 && test_conn ns_tx 169.254.1.4; then
        SUMMARY="$SUMMARY | $fwd is forwarding"
    else
        SUMMARY="$SUMMARY | $fwd is broken"
        continue
    fi

    start_trafficgen

    sudo -E ip netns exec ns_rx ${PYENV_PATH}/python3 ./packet_per_second_recorder.py \
        $NS_RX_IF -w pps_${fwd}_${D_PORT}${LOADED}${PACKET_SIZE}B_link${LINK_SPEED_RX}.csv

    sudo -E ip netns exec ns_tx ${PYENV_PATH}/python3 ./ping_logger.py fd00:0:0:1::4 \
        ping-${PACKET_SIZE}B-${LINK_SPEED_RX}-${D_PORT}${LOADED}-${fwd}.dat

    kill_trafficgen
done
echo "$SUMMARY"

if [[ $trafficgen_pid ]]; then
    kill $trafficgen_pid
fi
