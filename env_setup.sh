#!/usr/bin/env bash
set -x

netns()
{
        # Initialize new network namespaces
        ip netns add ns_tx
        ip netns add ns_rx

        # Add interfaces to namespaces
        ip link set cx5if1 netns ns_tx
        ip netns exec ns_tx ip addr add dev cx5if1 10.0.0.1/16
        ip netns exec ns_tx ip link set dev cx5if1 up
        ip link set cx5if0 netns ns_rx
        ip netns exec ns_rx ip addr add dev cx5if0 10.0.1.4/16
        ip netns exec ns_rx ip link set dev cx5if0 up

        # Execute commands within the namespaces like:
        # ip netns exec ns_tx iperf -s -B 10.0.0.1
        # ip netns exec ns_rx iperf -c 10.0.0.1 -B 10.0.0.4
}

xdp-net()
{
        ip addr add 10.0.0.2/24 dev ens16f0np0
        ip addr add 10.0.1.3/24 dev ens16f1np1
}

# Execute argument
"$@"
