chmod +x analyze.sh
crontab -l > backup_cron_tasks
crontab -r
./analyze.sh
crontab cron-file.txt
