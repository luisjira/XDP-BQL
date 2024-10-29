#!/usr/bin/env bash
set -x

netns()
{
        # Initialize new network namespaces
        ip netns add ns_tx
        ip netns add ns_rx

        # Add interfaces to namespaces
        ip link set cx5if1 netns ns_tx
	ip netns exec ns_tx ip addr add dev cx5if1 169.254.0.1/16
        ip netns exec ns_tx ip link set dev cx5if1 up
        ip netns exec ns_tx arp -s 169.254.1.4 1c:34:da:54:9a:a4
        ip link set cx5if0 netns ns_rx
	ip netns exec ns_rx ip addr add dev cx5if0 169.254.1.4/16
        ip netns exec ns_rx ip link set dev cx5if0 up
        ip netns exec ns_rx arp -s 169.254.0.1 1c:34:da:54:9a:a5

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
	nmcli conn modify "Wired connection 1" ipv4.addresses "169.254.0.2/24"
	nmcli conn modify "Wired connection 1" ipv4.method manual
	nmcli conn down "Wired connection 1"
	nmcli conn up "Wired connection 1"

	# Static IP for ens16f1np1
	nmcli conn modify "Wired connection 2" ipv4.addresses "169.254.1.3/24"
	nmcli conn modify "Wired connection 2" ipv4.method manual
	nmcli conn down "Wired connection 2"
	nmcli conn up "Wired connection 2"

	# Limit link speed to 1Gb/s on ens16f1np1
	ethtool -s ens16f1np1 speed 1000
}

# Execute argument
"$@"
