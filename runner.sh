#!/bin/bash
export HOME=/home/virilax
APP_DIR="/home/virilax/public_html/mostager.virilax.shop"
cd $APP_DIR

PORT=19080

# Check if port responds to health check
if /usr/bin/curl -s --connect-timeout 1 http://127.0.0.1:$PORT/api/v1/dashboard/stats > /dev/null 2>&1; then
    exit 0
fi

# Clean up stale processes
pkill -f "prod_server.py" 2>/dev/null
sleep 1

# Start production server
nohup /home/virilax/virtualenv/public_html/mostager.virilax.shop/3.9/bin/python prod_server.py > tmp/server.log 2>&1 &
