#!/bin/bash

# route add default gw 10.5.2.129

# Clean old executions
pkill wpa_supplicant 

# Associate external IP web service to domain
echo "#10.5.0.20      carlos.web.com" >> /etc/hosts

# Connect like a client
# wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
# dhclient wlan4

# Create a RADIUS AP
#freeradius -i 127.0.0.1 -p 1812 
#hostapd /ap/hostapd.conf -B
