#!/bin/bash

# Script to start the Stable node with port checking before launching Docker container

# Function to check if a port is available
check_port() {
    local port=$1
    if netstat -tuln | grep -q ":$port "; then
        return 1  # Port busy
    else
        return 0  # Port free
    fi
}

# Function to find an available port starting from a base port
find_available_port() {
    local base_port=$1
    local port=$base_port
    
    while ! check_port $port; do
        echo "[~] Port $port busy, trying $((port+1))..." >&2
        port=$((port+1))
        
        # Safety to avoid infinite loop
        if [ $port -gt $((base_port+1000)) ]; then
            echo "[!] Unable to find available port after 1000 attempts" >&2
            exit 1
        fi
    done
    
    echo $port
}

# Stop and remove existing container if it exists
# This should be done BEFORE checking port availability to free up any ports in use
if docker ps -a --format '{{.Names}}' | grep -q '^stable-node$'; then
    echo "[~] Stopping existing container..." >&2
    docker stop stable-node >/dev/null 2>&1
    echo "[~] Removing existing container..." >&2
    docker rm stable-node >/dev/null 2>&1
fi

# Default ports for Stable node
DEFAULT_P2P_PORT=26656
DEFAULT_RPC_PORT=26657
DEFAULT_API_PORT=1317
DEFAULT_JSON_RPC_PORT=8545
DEFAULT_WS_PORT=8546
DEFAULT_GRPC_PORT=9090

# Find available ports
echo "[~] Checking port availability..." >&2

# Find P2P port
P2P_PORT=$(find_available_port $DEFAULT_P2P_PORT)

# Find RPC port
RPC_PORT=$P2P_PORT
while [ $RPC_PORT -eq $P2P_PORT ]; do
    RPC_PORT=$(find_available_port $((RPC_PORT + 1)))
done

# Find API port (different from other ports)
API_PORT=$P2P_PORT
while [ $API_PORT -eq $P2P_PORT ] || [ $API_PORT -eq $RPC_PORT ]; do
    API_PORT=$(find_available_port $((API_PORT + 1)))
done

# Find JSON-RPC port (different from other ports)
JSON_RPC_PORT=$P2P_PORT
while [ $JSON_RPC_PORT -eq $P2P_PORT ] || [ $JSON_RPC_PORT -eq $RPC_PORT ] || [ $JSON_RPC_PORT -eq $API_PORT ]; do
    JSON_RPC_PORT=$(find_available_port $((JSON_RPC_PORT + 1)))
done

# Find WebSocket port (different from other ports)
WS_PORT=$P2P_PORT
while [ $WS_PORT -eq $P2P_PORT ] || [ $WS_PORT -eq $RPC_PORT ] || [ $WS_PORT -eq $API_PORT ] || [ $WS_PORT -eq $JSON_RPC_PORT ]; do
    WS_PORT=$(find_available_port $((WS_PORT + 1)))
done

# Find gRPC port (different from other ports)
GRPC_PORT=$P2P_PORT
while [ $GRPC_PORT -eq $P2P_PORT ] || [ $GRPC_PORT -eq $RPC_PORT ] || [ $GRPC_PORT -eq $API_PORT ] || [ $GRPC_PORT -eq $JSON_RPC_PORT ] || [ $GRPC_PORT -eq $WS_PORT ]; do
    GRPC_PORT=$(find_available_port $((GRPC_PORT + 1)))
done

# Show selected ports
echo "[✓] Using ports:" >&2
echo "  P2P Port: $P2P_PORT" >&2
echo "  RPC Port: $RPC_PORT" >&2
echo "  API Port: $API_PORT" >&2
echo "  JSON-RPC Port: $JSON_RPC_PORT" >&2
echo "  WebSocket Port: $WS_PORT" >&2
echo "  gRPC Port: $GRPC_PORT" >&2

# Install required dependencies
echo "[~] Installing dependencies..." >&2
apt update >/dev/null 2>&1
apt install -y wget curl jq lz4 unzip pv >/dev/null 2>&1

# Set environment variables
export MONIKER="docker-node"
export CHAIN_ID="stabletestnet_2201-1"

# Initialize node
echo "[~] Initializing node..." >&2
mkdir -p ~/.stabled
stabled init $MONIKER --chain-id $CHAIN_ID >/dev/null 2>&1

# Download and configure genesis
echo "[~] Configuring genesis..." >&2
mv ~/.stabled/config/genesis.json ~/.stabled/config/genesis.json.backup
wget https://stable-testnet-data.s3.us-east-1.amazonaws.com/stable_testnet_genesis.zip >/dev/null 2>&1
unzip stable_testnet_genesis.zip >/dev/null 2>&1
cp genesis.json ~/.stabled/config/genesis.json
rm stable_testnet_genesis.zip genesis.json

# Download and configure optimized settings
echo "[~] Configuring optimized settings..." >&2
wget https://stable-testnet-data.s3.us-east-1.amazonaws.com/rpc_node_config.zip >/dev/null 2>&1
unzip rpc_node_config.zip >/dev/null 2>&1
cp ~/.stabled/config/config.toml ~/.stabled/config/config.toml.backup
cp ~/.stabled/config/app.toml ~/.stabled/config/app.toml.backup
cp config.toml ~/.stabled/config/config.toml
cp app.toml ~/.stabled/config/app.toml
sed -i "s/^moniker = \".*\"/moniker = \"$MONIKER\"/" ~/.stabled/config/config.toml
rm rpc_node_config.zip config.toml app.toml

# Essential configuration updates
echo "[~] Updating configuration files..." >&2

# Enable JSON-RPC in app.toml
sed -i '/\[json-rpc\]/,/^\[.*\]/ s/enable = false/enable = true/' ~/.stabled/config/app.toml
sed -i '/\[json-rpc\]/,/^\[.*\]/ s/address = "127.0.0.1:8545"/address = "0.0.0.0:8545"/' ~/.stabled/config/app.toml
sed -i '/\[json-rpc\]/,/^\[.*\]/ s/ws-address = "127.0.0.1:8546"/ws-address = "0.0.0.0:8546"/' ~/.stabled/config/app.toml

# Configure P2P in config.toml
sed -i 's/^laddr = "tcp:\/\/127.0.0.1:26656"/laddr = "tcp:\/\/0.0.0.0:26656"/' ~/.stabled/config/config.toml
sed -i 's/^persistent_peers = ""/persistent_peers = "5ed0f977a26ccf290e184e364fb04e268ef16430@37.187.147.27:26656,128accd3e8ee379bfdf54560c21345451c7048c7@37.187.147.22:26656"/' ~/.stabled/config/config.toml
sed -i 's/^pex = false/pex = true/' ~/.stabled/config/config.toml

# Configure RPC in config.toml
sed -i 's/^laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' ~/.stabled/config/config.toml
sed -i 's/^cors_allowed_origins = \[\]/cors_allowed_origins = \["\*"\]/' ~/.stabled/config/config.toml

# Fix permissions for the stabled directory
echo "[~] Fixing permissions..." >&2
chown -R 1000:1000 ~/.stabled
chmod -R 755 ~/.stabled

# Download and extract snapshot if snapshot file doesn't exist in project directory
if [ ! -f "/root/stable-node/snapshot.tar.lz4" ]; then
    echo "[~] Downloading snapshot..." >&2
    cd /root/stable-node
    wget -c https://stable-snapshot.s3.eu-central-1.amazonaws.com/snapshot.tar.lz4 >/dev/null 2>&1
else
    echo "[~] Using existing snapshot file..." >&2
    cd /root/stable-node
fi

# Remove old data
echo "[~] Removing old data..." >&2
rm -rf ~/.stabled/data/*

# Extract snapshot
echo "[~] Extracting snapshot..." >&2
pv snapshot.tar.lz4 | tar -I lz4 -xf - -C ~/.stabled/ || tar -I lz4 -xvf snapshot.tar.lz4 -C ~/.stabled/

# Clean up snapshot file
rm snapshot.tar.lz4

# Update docker-compose.yml with the available ports
echo "[~] Updating docker-compose.yml with available ports..." >&2
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  stable-node:
    build: .
    container_name: stable-node
    ports:
      - "$P2P_PORT:26656"
      - "$RPC_PORT:26657"
      - "$API_PORT:1317"
      - "$JSON_RPC_PORT:8545"
      - "$WS_PORT:8546"
      - "$GRPC_PORT:9090"
    volumes:
      - ~/.stabled:/home/stable/.stabled
    environment:
      - MONIKER=docker-node
      - CHAIN_ID=stabletestnet_2201-1
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOF

# Start the container
echo "[~] Starting Stable node container..." >&2
docker compose up -d

echo "[✓] Stable node started successfully!" >&2
echo "View logs with: docker compose logs -f" >&2
echo "P2P Port: $P2P_PORT" > ports.info
echo "RPC Port: $RPC_PORT" >> ports.info
echo "API Port: $API_PORT" >> ports.info
echo "JSON-RPC Port: $JSON_RPC_PORT" >> ports.info
echo "WebSocket Port: $WS_PORT" >> ports.info
echo "gRPC Port: $GRPC_PORT" >> ports.info