#!/bin/bash

route add default gw 10.5.1.1
route del default gw 10.5.1.254

# Redirect malicious traffic SSH to Cowrie
iptables -t nat -A PREROUTING -s 10.5.0.0/24 -p tcp --dport 22 -j DNAT --to-destination :2222

/usr/sbin/sshd
su - cowrie -c "/home/cowrie/cowrie/bin/cowrie start"
apachectl -D FOREGROUND
