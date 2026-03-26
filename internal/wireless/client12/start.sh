#!/bin/bash

# route add default gw 10.5.2.129

# Clean old executions
pkill wpa_supplicant 
sleep 1

# Associate external IP web service to domain
echo "#10.5.0.20      carlos.web.com" >> /etc/hosts

# Check if interface is passed
if [[ -z "$2" ]]; then
    echo "Usage: command <wirelless-interface> <AP-MAC>"
    exit 1
fi
IFACE="$1"

# Check if interface exists 
if ! ip link show "$IFACE" > /dev/null 2>&1; then
    echo "Error: '$IFACE' not exists."
    exit 1
fi

# Expresión regular para validar una MAC en formato xx:xx:xx:xx:xx:xx
if [[ ! "$2" =~ ^([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2}$ ]]; then
    echo "Error: MAC no válida: $2" >&2
    exit 1
fi
MAC="$2"

# Connect to WLAN
wpa_supplicant -i "$IFACE" -c wpa_supplicant.conf -B
wpa_cli -i "$IFACE" wps_reg "$MAC" 94229882
dhclient "$IFACE"
