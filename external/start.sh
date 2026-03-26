#!/bin/bash

route add default gw 10.5.0.1
route del default gw 10.5.0.254 

/usr/sbin/sshd 
apachectl -D FOREGROUND

# To connect with VPN execute:
# openvpn --config /etc/openvpn/client.conf 
