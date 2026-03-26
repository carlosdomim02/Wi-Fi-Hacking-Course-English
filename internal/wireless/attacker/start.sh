#!/bin/bash

# route add default gw 10.5.2.129

# Clean old executions
pkill wpa_supplicant 

# Associate external IP web service to domain
echo "#10.5.0.20      carlos.web.com" >> /etc/hosts
