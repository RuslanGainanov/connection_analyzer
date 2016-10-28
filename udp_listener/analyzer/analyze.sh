#!/bin/sh
ruby /var/udp_listener/analyzer/connections_users.rb >> /var/log/udp_listener/analyzer.log 2>&1
