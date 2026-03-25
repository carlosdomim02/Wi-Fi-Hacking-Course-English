#!/bin/bash

route add default gw 10.5.1.1
route del default gw 10.5.1.254

/etc/init.d/syslog-ng restart
service ssh start
# service fail2ban start
apachectl -D FOREGROUND