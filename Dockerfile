FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    jq \
    lz4 \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create user
RUN useradd -m -u 1000 stable

# Set working directory
WORKDIR /home/stable

# Download and install Stable node binary
RUN wget https://stable-testnet-data.s3.us-east-1.amazonaws.com/stabled-1.1.2-linux-amd64-testnet.tar.gz && \
    tar -xzf stabled-1.1.2-linux-amd64-testnet.tar.gz && \
    mv stabled /usr/bin/ && \
    rm stabled-1.1.2-linux-amd64-testnet.tar.gz

# Switch to stable user
USER stable

# Expose ports
EXPOSE 26656 26657 1317 8545 8546 9090

# Set environment variables
ENV MONIKER=docker-node
ENV CHAIN_ID=stabletestnet_2201-1

# Create data directory
RUN mkdir -p /home/stable/.stabled

# Initialize node
RUN stabled init $MONIKER --chain-id $CHAIN_ID

# Download and configure genesis
RUN mv /home/stable/.stabled/config/genesis.json /home/stable/.stabled/config/genesis.json.backup && \
    wget https://stable-testnet-data.s3.us-east-1.amazonaws.com/stable_testnet_genesis.zip && \
    unzip stable_testnet_genesis.zip && \
    cp genesis.json /home/stable/.stabled/config/genesis.json && \
    rm stable_testnet_genesis.zip genesis.json

# Download and configure optimized settings
RUN wget https://stable-testnet-data.s3.us-east-1.amazonaws.com/rpc_node_config.zip && \
    unzip rpc_node_config.zip && \
    cp /home/stable/.stabled/config/config.toml /home/stable/.stabled/config/config.toml.backup && \
    cp /home/stable/.stabled/config/app.toml /home/stable/.stabled/config/app.toml.backup && \
    cp config.toml /home/stable/.stabled/config/config.toml && \
    cp app.toml /home/stable/.stabled/config/app.toml && \
    sed -i "s/^moniker = \".*\"/moniker = \"$MONIKER\"/" /home/stable/.stabled/config/config.toml && \
    rm rpc_node_config.zip config.toml app.toml

# Configure app.toml for JSON-RPC (additional configuration)
RUN sed -i '/\[json-rpc\]/,/^\[.*\]/ s/enable = false/enable = true/' /home/stable/.stabled/config/app.toml && \
    sed -i '/\[json-rpc\]/,/^\[.*\]/ s/address = "127.0.0.1:8545"/address = "0.0.0.0:8545"/' /home/stable/.stabled/config/app.toml && \
    sed -i '/\[json-rpc\]/,/^\[.*\]/ s/ws-address = "127.0.0.1:8546"/ws-address = "0.0.0.0:8546"/' /home/stable/.stabled/config/app.toml

# Configure config.toml for P2P and RPC
RUN sed -i 's/^laddr = "tcp:\/\/127.0.0.1:26656"/laddr = "tcp:\/\/0.0.0.0:26656"/' /home/stable/.stabled/config/config.toml && \
    sed -i 's/^laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' /home/stable/.stabled/config/config.toml && \
    sed -i 's/^cors_allowed_origins = \[\]/cors_allowed_origins = \["\*"\]/' /home/stable/.stabled/config/config.toml && \
    sed -i 's/^persistent_peers = ""/persistent_peers = "5ed0f977a26ccf290e184e364fb04e268ef16430@37.187.147.27:26656,128accd3e8ee379bfdf54560c21345451c7048c7@37.187.147.22:26656"/' /home/stable/.stabled/config/config.toml

ENTRYPOINT ["stabled"]
CMD ["start", "--chain-id", "stabletestnet_2201-1"]