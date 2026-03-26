#!/bin/bash

# route add default gw 10.5.2.129

# Clean old executions
pkill wpa_supplicant 

# Associate external IP web service to domain
echo "#10.5.0.20      carlos.web.com" >> /etc/hosts

# Use them to connect
#wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
#wpa_cli -i wlan4 wps_reg 02:00:00:00:00:00 94229882
#dhclient wlan4
