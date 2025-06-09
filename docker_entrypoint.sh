#!/bin/bash

set -euo pipefail

CONFIG_FILE="/root/.bitcoin/start9/config.yaml"
export EMBASSY_IP=$(ip -4 route list match 0/0 | awk '{print $3}')
export PEER_TOR_ADDRESS=$(yq e '.peer-tor-address' "$CONFIG_FILE")
export RPC_TOR_ADDRESS=$(yq e '.rpc-tor-address' "$CONFIG_FILE")

# Start Flask UI in background
echo "Starting bitcoin Stats Monitoring app..."
python3 /app/bitcoin-stats.py &

# Start the Bitcoin manager (main process)
echo "Starting bitcoind-manager..."
exec tini -p SIGTERM -- bitcoind-manager
