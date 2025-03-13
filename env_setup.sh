#!/usr/bin/env bash
set -x

NS_TX_IF=cx5if1
NS_RX_IF=cx5if0

XDP_TX_IF=ens16f0np0
XDP_RX_IF=ens16f1np1

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
        ip link set $NS_TX_IF netns ns_tx
	ip netns exec ns_tx ip addr flush dev $NS_TX_IF
	ip netns exec ns_tx ip addr add dev $NS_TX_IF 169.254.0.1/16
	ip netns exec ns_tx ip addr add dev $NS_TX_IF fd00::1/64
        ip netns exec ns_tx ip link set dev $NS_TX_IF up
        ip netns exec ns_tx ip route add fd00:0:0:1::/64 via fd00::2
	ip netns exec ns_tx ip -6 neighbor add fd00::2 lladdr 1c:34:da:54:9a:a4 dev $NS_TX_IF
	ip netns exec ns_tx arp -s 169.254.1.4 1c:34:da:54:9a:a4

        ip link set $NS_RX_IF netns ns_rx
	ip netns exec ns_rx ip addr flush dev $NS_RX_IF
	ip netns exec ns_rx ip addr add dev $NS_RX_IF 169.254.1.4/16
	ip netns exec ns_rx ip addr add dev $NS_RX_IF fd00:0:0:1::4/64
        ip netns exec ns_rx ip link set dev $NS_RX_IF up
        ip netns exec ns_rx ip route add fd00::/64 via fd00:0:0:1::3
	ip netns exec ns_rx ip -6 neighbor add fd00:0:0:1::3 lladdr 1c:34:da:54:9a:a5 dev $NS_RX_IF
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

	# Static IP for $XDP_TX_IF
	nmcli device set $XDP_TX_IF managed no
	ip addr flush dev $XDP_TX_IF
	ip addr add fd00:0:0:0::2/64 dev $XDP_TX_IF
	ip addr add 169.254.0.2/24 dev $XDP_TX_IF
        ip link set up dev $XDP_TX_IF
	ip -6 neighbor add fd00::1 lladdr b8:83:03:6f:63:51 dev $XDP_TX_IF
	arp -s 169.254.0.1 b8:83:03:6f:63:51
	sysctl -w net.ipv6.conf.$XDP_TX_IF.forwarding=1
	sysctl -w net.ipv4.conf.$XDP_TX_IF.forwarding=1

	# Static IP for $XDP_RX_IF
	nmcli device set $XDP_RX_IF managed no
	ip addr flush dev $XDP_RX_IF
	ip addr add fd00:0:0:1::3/64 dev $XDP_RX_IF
	ip addr add 169.254.1.3/24 dev $XDP_RX_IF
        ip link set up dev $XDP_RX_IF
	ip -6 neighbor add fd00:0:0:1::4 lladdr b8:83:03:6f:63:50 dev $XDP_RX_IF
	arp -s 169.254.1.4 b8:83:03:6f:63:50
	sysctl -w net.ipv6.conf.$XDP_RX_IF.forwarding=1
	sysctl -w net.ipv4.conf.$XDP_RX_IF.forwarding=1

	# Limit link speed to 1Gb/s on $XDP_RX_IF
	# ethtool -s $XDP_RX_IF speed 1000
}

limit()
{
	ethtool -s $XDP_TX_IF speed 10000
	ethtool -s $XDP_RX_IF speed 1000
}

unlimit()
{
	ethtool -s $XDP_TX_IF speed 100000
	ethtool -s $XDP_RX_IF speed 100000
}

# Execute argument
"$@"
