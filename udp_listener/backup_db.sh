#!/bin/sh
influxd backup -database itgrp_listen /root/influxdb/backup/itgrp_listen/`date +%Y.%m.%d_%H.%M.%S`
