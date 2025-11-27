#!/bin/bash

# Script to monitor the synchronization progress of the Stable node

echo "=== Stable Node Synchronization Monitoring ==="
echo "Press Ctrl+C to stop"
echo ""

# Infinite loop to monitor synchronization
while true; do
    # Get synchronization information
    sync_info=$(cd /root/Stable_Node && docker compose exec stable-node curl -s localhost:26657/status 2>/dev/null | jq '.result.sync_info' 2>/dev/null)
    
    # Get peer information
    peer_info=$(cd /root/Stable_Node && docker compose exec stable-node curl -s localhost:26657/net_info 2>/dev/null | jq '.result' 2>/dev/null)
    
    if [ -n "$sync_info" ] && [ -n "$peer_info" ]; then
        # Extract relevant information
        latest_block_height=$(echo "$sync_info" | jq -r '.latest_block_height')
        catching_up=$(echo "$sync_info" | jq -r '.catching_up')
        latest_block_time=$(echo "$sync_info" | jq -r '.latest_block_time')
        n_peers=$(echo "$peer_info" | jq -r '.n_peers')
        
        # Display information
        echo "=== $(date) ==="
        echo "Current block height: $latest_block_height"
        echo "Catching up: $catching_up"
        echo "Latest block time: $latest_block_time"
        echo "Connected peers: $n_peers"
        echo "----------------------------------------"
    else
        echo "=== $(date) ==="
        echo "Unable to retrieve synchronization information"
        echo "Check that the container is running"
        echo "----------------------------------------"
    fi
    
    # Wait 10 seconds before next check
    sleep 10
done