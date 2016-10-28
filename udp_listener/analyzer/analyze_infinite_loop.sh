#!/bin/sh
while true
do
    ruby /var/udp_listener/analyzer/connections_users.rb >> /var/log/udp_listener/analyzer.log 2>&1
    sleep 10
done 
