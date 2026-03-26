#!/bin/bash

# Allow connections with WLAN
ip route add 10.5.2.128/25 via 10.5.2.24

# Allow forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Change defaults policies to drop input and forward traffic and allow output and loopback traffic
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -i lo -j ACCEPT

# Allow response traffic at TCP and UDP traffic to fw machine
iptables -A INPUT -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT             #icmp packets are considered RELATED traffic to iptables
iptables -A INPUT -p udp -m state --state ESTABLISHED,RELATED -j ACCEPT
#iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT                       #Accept ping requests to fw (changed by limit option)

# Allow response traffic at ICMP, TCP and UDP traffic that go through fw machine
iptables -A FORWARD -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -p udp -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -p icmp --icmp-type echo-reply -j ACCEPT                        #icmp packets are considered RELATED traffic to iptables

# Allow TCP, UDP and ICMP since intranet to extranet
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.0.0/24 -p tcp -j ACCEPT
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.0.0/24 -p udp -j ACCEPT
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.0.0/24 -p icmp -j ACCEPT

# Masquerade Intranet to extranet comunications (using SNAT because IP is always the same)
iptables -t nat -A POSTROUTING -s 10.5.2.0/24 -d 10.5.0.0/24 -j SNAT --to 10.5.0.1

# Allow HTTP request since intranet and extranet to servers (dmz net)
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.1.0/24 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -s 10.5.0.0/24 -d 10.5.1.0/24 -p tcp --dport 80 -j ACCEPT

# Limit icmp request to fw (avoid DOS attacks)
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/minute --limit-burst 10 -j ACCEPT

# Allow SHH admin comunications since intranet to dmz servers
# iptables -A FORWARD -s 10.5.2.20 -d 10.5.1.0/24 -p tcp --dport 22 -j ACCEPT        # for more secure divide this rule in two:
#iptables -A FORWARD -s 10.5.2.20 -d 10.5.1.20 -p tcp --dport 22 -j ACCEPT           # for more restrictive admin conexion
#iptables -A FORWARD -s 10.5.2.20 -d 10.5.1.21 -p tcp --dport 2222 -j ACCEPT
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.1.20 -p tcp --dport 22 -j ACCEPT          # Allow all internal network to admin dmz servers
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.1.21 -p tcp --dport 2222 -j ACCEPT

# Allow HTTPS request since intranet and extranet to servers (dmz net)
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.1.0/24 -p tcp --dport 443 -j ACCEPT
iptables -A FORWARD -s 10.5.0.0/24 -d 10.5.1.0/24 -p tcp --dport 443 -j ACCEPT

# Define VPN conection 
#iptables -A FORWARD -s 10.5.2.22 -d 10.5.1.20 -p tcp --dport 22 -j ACCEPT            #neccesary for vpn admin connection (for more restrictive admin conexion)
#iptables -A FORWARD -s 10.5.2.22 -d 10.5.1.21 -p tcp --dport 2222 -j ACCEPT               
iptables -A FORWARD -s 10.5.0.0/24 -d 10.5.2.22 -p udp --dport 1194 -j ACCEPT
iptables -A FORWARD -s 10.5.2.22 -d 10.5.2.0/24 -p udp --sport 1194 -j ACCEPT

# Allow external SSH traffic to dmz1 machine (in this machine this traffic is redirect to cowrie honeypot)
iptables -A FORWARD -s 10.5.0.0/24 -d 10.5.1.20 -p tcp --dport 22 -j ACCEPT

/usr/sbin/sshd -D
