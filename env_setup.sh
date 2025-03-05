#!/usr/bin/env bash
set -x

netns()
{
        # Initialize new network namespaces
        ip netns add ns_tx
        ip netns add ns_rx

        # Add interfaces to namespaces
        ip link set cx5if1 netns ns_tx
	ip netns exec ns_tx ip addr add dev cx5if1 fd00::1/63
        ip netns exec ns_tx ip link set dev cx5if1 up
	ip netns exec ns_tx ip -6 neighbor add fd00::2 lladdr 1c:34:da:54:9a:a4 dev cx5if1

        ip link set cx5if0 netns ns_rx
	ip netns exec ns_rx ip addr add dev cx5if0 fd00:0:0:1::4/63
        ip netns exec ns_rx ip link set dev cx5if0 up
	ip netns exec ns_rx ip -6 neighbor add fd00:0:0:1::3 lladdr 1c:34:da:54:9a:a5 dev cx5if0

        # Execute commands within the namespaces like:
	# ip netns exec ns_tx iperf -s -B 169.254.0.1
	# ip netns exec ns_rx iperf -c 169.254.0.1 -B 169.254.1.4
}

xdp-net()
{
	# This approach is reset by NetworkManager
        #ip addr add 10.0.0.2/24 dev ens16f0np0
        #ip addr add 10.0.1.3/24 dev ens16f1np1

	# Static IP for ens16f0np0
	nmcli device set ens16f0np0 managed no
	ip addr flush dev ens16f0np0
	ip addr add fd00:0:0:0::2/64 dev ens16f0np0
        ip link set up dev ens16f0np0

	# Static IP for ens16f1np1
	nmcli device set ens16f1np1 managed no
	ip addr flush dev ens16f1np1
	ip addr add fd00:0:0:1::3/64 dev ens16f1np1
        ip link set up dev ens16f1np1

	# Limit link speed to 1Gb/s on ens16f1np1
	ethtool -s ens16f1np1 speed 1000
}

# Execute argument
"$@"
