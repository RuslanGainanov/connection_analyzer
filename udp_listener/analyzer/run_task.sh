chmod +x /var/udp_listener/analyzer/analyze.sh
crontab -l > /var/udp_listener/analyzer/backup_cron_tasks
crontab -r
/var/udp_listener/analyzer/analyze.sh
crontab /var/udp_listener/analyzer/cron-file.txt
