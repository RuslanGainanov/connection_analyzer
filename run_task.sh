chmod +x /var/connection_analyzer/analyze.sh
crontab -l > /var/connection_analyzer/backup_cron_tasks
crontab -r
/var/connection_analyzer/analyze.sh
crontab /var/connection_analyzer/cron-file.txt
