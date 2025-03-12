#!/usr/bin/env bash
set -x
FWDS=('kernel' 'xdp' 'xdp-queueing' 'xdp-bql' 'xdp-bql-icmp')

test_conn_v6()
{
    ip netns exec ns_tx ping -c 1 -6  fd00:0:0:1::4 > /dev/null 2>&1
    return $?
}

test_conn_v4()
{
    ip netns exec ns_tx ping -c 1 -4  169.254.1.4 > /dev/null 2>&1
    return $?
}

xdp-bql-icmp()
{
    git checkout xdp-forward-bql-icmp-prio
}

xdp-bql()
{
    git checkout xdp-forward-bql
}

xdp-queueing()
{
    git checkout xdp-forward-queueing
}

xdp()
{
    git checkout master
}

kernel()
{
    exit 0
}


# Load forwarding schemes and run test loaded/unloaded
for fwd in "${FWDS[@]}"
do
    ssh nslrackvm "sudo -E ~/XDP-BQL/fwd-loader.sh ${fwd}"
    if test_conn_v6 && test_conn_v4; then
        echo "$fwd is reachable"
    else
        echo "$fwd is unreachable"
    fi
done

