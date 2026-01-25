#!/bin/bash

# Auto-pull script - fetches remote changes every 20-30 seconds

cd "$(dirname "$0")"

while true; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pulling from remote..."
    git pull --rebase 2>&1
    
    # Random sleep between 20-30 seconds
    sleep_time=$((20 + RANDOM % 11))
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Next pull in ${sleep_time}s"
    sleep $sleep_time
done
