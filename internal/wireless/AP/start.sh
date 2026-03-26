#!/bin/bash

route add default gw 10.5.2.1
route del default gw 10.5.2.254

# Clean old executions
pkill hostapd 
pkill dhcpd 
sleep 1

# Allow forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Drop forwarding traffic by default
iptables -P FORWARD DROP

# Allow forwarding LAN traffic
iptables -A FORWARD -i wlan0 -o wlan0 -s 10.5.2.128/26 -d 10.5.2.128/26 -j ACCEPT

# Allow and masquerade forwarding traffic from wireless to wired interface 
iptables -A FORWARD -s 10.5.2.128/26 -i wlan0 -o eth0 -j ACCEPT
iptables -A FORWARD -d 10.5.2.128/26 -i eth0 -o wlan0 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.5.2.128/26 -o eth0 -j SNAT --to 10.5.2.24

# Allow loopback traffic
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Setup DHCP
touch /var/lib/dhcp/dhcpd.leases
chown root:root /var/lib/dhcp/dhcpd.leases
dhcpd -cf /etc/dhcp/dhcpd.conf wlan0

# Setup hostapd (access point) 
hostapd /ap/hostapd.conf -B
