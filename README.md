# Stable Node Docker Setup

This repository contains all the necessary files to run a Stable node using Docker with automatic port management and snapshot synchronization.

## Features

- Docker containerized Stable node
- Automatic port availability checking
- Snapshot-based fast synchronization
- Automatic cleanup of temporary files
- All services running in a single directory

## Prerequisites

- Docker and Docker Compose installed
- Linux system (tested on Ubuntu 22.04)

## Quick Start

1. Make the startup script executable:
   ```bash
   chmod +x start-stable-node-with-port-check.sh
   ```

2. Run the startup script:
   ```bash
   ./start-stable-node-with-port-check.sh
   ```

The script will automatically:
- Check for available ports
- Download and configure the node
- Download and extract the latest snapshot
- Start the Docker container with proper port mapping

## Services and Ports

The node exposes the following services:

- **P2P**: 26656 (or first available port)
- **RPC**: 26657 (or first available port after P2P)
- **API**: 1317 (or first available port after RPC)
- **JSON-RPC**: 8545 (or first available port after API)
- **WebSocket**: 8546 (or first available port after JSON-RPC)
- **gRPC**: 9090 (or first available port after WebSocket)

Actual ports used will be displayed when the script runs.

## Monitoring Node Status

### Check Synchronization Status

To check if the node is fully synchronized:
```bash
docker compose exec stable-node curl -s localhost:26657/status | jq '.result.sync_info'
```

This will show:
- `latest_block_height`: Current block height of your node
- `catching_up`: `true` if still syncing, `false` if fully synchronized

### Check Peer Connections

To see how many peers your node is connected to:
```bash
docker compose exec stable-node curl -s localhost:26657/net_info | jq '.result.n_peers'
```

### Check Latest Block

To see the latest block processed by your node:
```bash
docker compose exec stable-node curl -s localhost:26657/status | jq '.result.sync_info.latest_block_height'
```

## General Monitoring

To view the node logs:
```bash
docker compose logs -f
```

To check the node status:
```bash
docker compose ps
```

## Configuration Files

The node configuration files are stored in `~/.stabled/`:
- `config.toml`: Core Tendermint/CometBFT configuration
- `app.toml`: Application-specific configuration
- `genesis.json`: Genesis file

## Stopping the Node

To stop the node:
```bash
docker compose down
```

## Cleaning Up

To completely remove all node data:
```bash
docker compose down -v
rm -rf ~/.stabled
```

## Troubleshooting

If the node fails to start:
1. Check the logs: `docker compose logs`
2. Ensure ports are available
3. Verify Docker is running properly
4. Check disk space availability