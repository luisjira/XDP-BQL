#!/usr/bin/env bash
set -x
DIR=~/xdp-tools/xdp-forward
IF1=ens16f0np0
IF2=ens16f1np1

unload()
{
    ./xdp-forward unload $IF1 $IF2
    make clean
    sudo rm /sys/fs/bpf/dst_port_state
}

load()
{
    make
    ./xdp-forward load $IF1 $IF2
}

xdp-bql-icmp()
{
    git checkout xdp-forward-bql-icmp-prio
}

xdp-bql()
{
    git checkout xdp-forward-bql
}

xdp-q()
{
    git checkout xdp-forward-queueing
}

xdp-q-icmp()
{
    git checkout xdp-forward-queueing-icmp
}

xdp()
{
    git checkout master
}

xdp-icmp()
{
    git checkout master-icmp
}

kernel()
{
    exit 0
}

# Change to DIR, unload xdp program, switch branch and load new xdp-program
# If kernel, only unload old xdp program
# Must be run as root to (un)load xdp programs and remove dst_port_state map
cd $DIR
unload
"$@"
load
