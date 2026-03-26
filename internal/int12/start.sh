#!/bin/bash

# id_rsa password = "1234"

route add default gw 10.5.2.1
route del default gw 10.5.2.254

# Allow connections with WLAN
ip route add 10.5.2.128/26 via 10.5.2.24

/usr/sbin/sshd -D
