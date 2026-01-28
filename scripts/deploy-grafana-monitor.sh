#!/bin/bash
# Script to deploy the Moltbot Health Monitoring Stack (Grafana + JSON Datasource).
# This script must be run on the same VPS as the Moltbot Gateway.

set -e

GATEWAY_PORT="18789"
GRAFANA_PORT="3000"
DATASOURCE_NAME="Moltbot-Health"
GRAFANA_PASS="admin" # Default pass, user should change this after login

echo "========================================================="
echo "Moltbot Real-time Health Monitor Setup (Grafana)"
echo "========================================================="

# 1. Check for and Install Docker if necessary
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    # Note: Requires a re-login or use of sudo/newgrp for non-root users
    echo "Docker installed. Restarting Docker daemon to ensure service is ready."
    service docker restart
else
    echo "Docker is already installed."
fi

# 2. Check for Moltbot Gateway IP (for Grafana Data Source)
VPS_IP=$(hostname -I | awk '{print $1}')
if [ -z "$VPS_IP" ]; then
    echo "Error: Could not determine VPS IP. Exiting."
    exit 1
fi
echo "VPS IP detected: $VPS_IP"

# 3. Deploy Grafana Container
if docker ps -a --format '{{.Names}}' | grep -q grafana; then
    echo "Grafana container already exists. Restarting..."
    docker restart grafana
else
    echo "Pulling and running Grafana container on port $GRAFANA_PORT..."
    docker run -d --name grafana -p $GRAFANA_PORT:$GRAFANA_PORT grafana/grafana-oss
fi

# Wait for Grafana to start (Give it 10 seconds)
echo "Waiting for Grafana service to initialize..."
sleep 10

# 4. Install Simple JSON Data Source Plugin
echo "Installing Grafana Simple JSON Data Source plugin..."
docker exec grafana grafana-cli plugins install grafana-simple-json-datasource

# Restart Grafana to load plugin (required step)
echo "Restarting Grafana to load plugin..."
docker restart grafana
sleep 5 # Wait for restart

# 5. Add Moltbot Data Source
# Grafana URL for the data source API
GRAFANA_API_URL="http://admin:$GRAFANA_PASS@localhost:$GRAFANA_PORT/api/datasources"
MOLTBOT_HEALTH_URL="http://${VPS_IP}:${GATEWAY_PORT}"

echo "Creating Moltbot-Health Data Source pointing to $MOLTBOT_HEALTH_URL..."

# Send the API request to create the data source
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{
      "name": "'$DATASOURCE_NAME'",
      "type": "simple-json",
      "url": "'$MOLTBOT_HEALTH_URL'",
      "access": "proxy",
      "isDefault": true,
      "jsonData": {
        "httpMethod": "GET",
        "path": "/health"
      }
    }' \
  $GRAFANA_API_URL | grep -q "Datasource added"

if [ $? -eq 0 ]; then
    echo "✅ Success! Datasource '$DATASOURCE_NAME' added to Grafana."
else
    echo "❌ ERROR: Failed to add Moltbot Datasource via API. Check Grafana logs (docker logs grafana)."
fi

echo "========================================================="
echo "Deployment Complete."
echo "Access Grafana at: http://${VPS_IP}:${GRAFANA_PORT}"
echo "Default Credentials: admin / admin"
echo "NOTE: Ensure port $GRAFANA_PORT is open on your firewall!"
echo "========================================================="