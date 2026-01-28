#!/bin/bash
# Script to set up the Real-time Health Monitoring Dashboard (External Demo)
# This dashboard uses the /health API endpoint implemented in this Moltbot feature branch.

set -e

REPO_URL="https://github.com/sudoBot-code/sudobot-dashboard.git"
DASHBOARD_DIR="./.monitoring-dashboard"
API_PORT="8008"

echo "========================================================="
echo "Moltbot Real-time Monitoring Dashboard Setup"
echo "========================================================="

# 1. Clone the dashboard repository
if [ -d "$DASHBOARD_DIR" ]; then
    echo "Directory $DASHBOARD_DIR already exists. Skipping clone."
else
    echo "Cloning demo dashboard from $REPO_URL..."
    git clone $REPO_URL $DASHBOARD_DIR
fi

cd $DASHBOARD_DIR

# 2. Install Node.js dependencies for the API server
if [ -f "package.json" ]; then
    echo "Installing Node.js dependencies..."
    pnpm install
else
    echo "Error: package.json not found in $DASHBOARD_DIR."
    exit 1
fi

# 3. Create a non-committed .env file with the current VPS IP
echo "Checking VPS IP..."
VPS_IP=$(hostname -I | awk '{print $1}')
if [ -z "$VPS_IP" ]; then
    echo "Error: Could not determine VPS IP. Cannot proceed with .env creation."
    exit 1
fi

echo "VPS_IP=$VPS_IP" > .env
echo "API_PORT=$API_PORT" >> .env
echo "Created non-committed .env file for API server (IP: $VPS_IP)."

# 4. Start the Node.js API server in the background
echo "Starting real-time API server on port $API_PORT..."
# Using nohup and & to ensure it runs independently of the current shell
nohup node server.js > api.log 2>&1 &
echo "API server started. Check api.log for details."
echo "Access the dashboard frontend via GitHub Pages (Frontend pulls data from your VPS):"
echo "https://sudobot-code.github.io/sudobot-dashboard/"
echo "========================================================="
echo "NOTE: Ensure port $API_PORT is open on your firewall!"
echo "========================================================="