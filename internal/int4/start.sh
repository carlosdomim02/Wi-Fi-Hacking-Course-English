#!/bin/bash

route del default gw 10.5.2.254
route add default gw 10.5.2.1

# Allow connections with WLAN
ip route add 10.5.2.128/26 via 10.5.2.24

/usr/sbin/sshd 
/usr/sbin/apache2ctl -DFOREGROUND
