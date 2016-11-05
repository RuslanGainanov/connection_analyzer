#!/bin/bash
su -s /bin/sh - ruby_runner -c /var/udp_listener/run_dhcp.sh &

su -s /bin/sh - ruby_runner -c /var/udp_listener/run_nps.sh &

su -s /bin/sh - ruby_runner -c /var/udp_listener/run_syslog.sh &
