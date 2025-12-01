#!/bin/bash


echo "30 6 * * 1 find /var/log -type f -mtime +30 -delete" | crontab -
