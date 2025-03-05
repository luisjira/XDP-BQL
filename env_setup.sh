#!/usr/bin/env bash
set -x

netns()
{
        # Remove old configuration
	if ip netns list | grep -q .; then
	    ip netns del ns_tx
	    ip netns del ns_rx
            echo "Waiting for interface reset"
            sleep 1
	fi

	# Initialize new network namespaces
        ip netns add ns_tx
        ip netns add ns_rx

        # Add interfaces to namespaces
        ip link set cx5if1 netns ns_tx
	ip netns exec ns_tx ip addr flush dev cx5if1
	ip netns exec ns_tx ip addr add dev cx5if1 fd00::1/64
        ip netns exec ns_tx ip link set dev cx5if1 up
        ip netns exec ns_tx ip route add fd00:0:0:1::/64 via fd00::2
	ip netns exec ns_tx ip -6 neighbor add fd00::2 lladdr 1c:34:da:54:9a:a4 dev cx5if1

        ip link set cx5if0 netns ns_rx
	ip netns exec ns_tx ip addr flush dev cx5if0
	ip netns exec ns_rx ip addr add dev cx5if0 fd00:0:0:1::4/64
        ip netns exec ns_rx ip link set dev cx5if0 up
        ip netns exec ns_rx ip route add fd00::/64 via fd00:0:0:1::3
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
	ip -6 neighbor add fd00::1 lladdr b8:83:03:6f:63:51 dev ens16f0np0
	# sysctl -w net.ipv6.conf.ens16f0np0.forwarding=1
	# sysctl -w net.ipv6.conf.ens16f0np0.proxy_ndp=1

	# Static IP for ens16f1np1
	nmcli device set ens16f1np1 managed no
	ip addr flush dev ens16f1np1
	ip addr add fd00:0:0:1::3/64 dev ens16f1np1
        ip link set up dev ens16f1np1
	ip -6 neighbor add fd00:0:0:1::4 lladdr b8:83:03:6f:63:50 dev ens16f1np1

	# Limit link speed to 1Gb/s on ens16f1np1
	ethtool -s ens16f1np1 speed 1000
}

# Execute argument
"$@"
