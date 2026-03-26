#!/bin/bash

route add default gw 10.5.2.1
route del default gw 10.5.2.254

# Allow connections with WLAN
ip route add 10.5.2.128/25 via 10.5.2.24

# Allow and config VPN
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -s 10.8.0.0/24 -j ACCEPT

openvpn --config /etc/openvpn/server.conf &
/usr/sbin/sshd -D

# Generate private and public keys
# wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey 