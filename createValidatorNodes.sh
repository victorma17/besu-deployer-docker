#!/bin/bash

NUM_VALIDATORS=4  # Total number of validator nodes
BASE_IP="172.16.240"
NETWORK_NAME="besu-network"
BESU_VERSION="24.12.2"

# Create Docker network if it does not exist
docker network inspect $NETWORK_NAME >/dev/null 2>&1 || \
docker network create --driver=bridge --subnet=$BASE_IP.0/24 $NETWORK_NAME

# Loop through validator nodes
for i in $(seq 2 $NUM_VALIDATORS); do
  NODE_NAME="node$i"
  NODE_DIR="QBFT-Network/Node-$i/data"
  mkdir -p "$NODE_DIR"

  PORT_OFFSET=$((i - 1))
  P2P_PORT=$((30304 + PORT_OFFSET))
  RPC_PORT=$((8546 + PORT_OFFSET))
  METRICS_PORT=$((9546 + PORT_OFFSET))
  NODE_IP="$BASE_IP.$((30 + PORT_OFFSET))"

  echo "Starting $NODE_NAME with IP $NODE_IP and ports: P2P=$P2P_PORT, RPC=$RPC_PORT, METRICS=$METRICS_PORT"

  docker run -d --name $NODE_NAME \
    -v "$(pwd)/config:/opt/besu/config" \
    -v "$(pwd)/QBFT-Network/Node-$i/data:/opt/besu/data" \
    -p $P2P_PORT:$P2P_PORT \
    -p $RPC_PORT:$RPC_PORT \
    -p $METRICS_PORT:$METRICS_PORT \
    --network $NETWORK_NAME \
    --ip $NODE_IP \
    hyperledger/besu:$BESU_VERSION \
    --config-file=/opt/besu/config/configValidators.toml \
    --p2p-port=$P2P_PORT \
    --rpc-http-port=$RPC_PORT \
    --metrics-port=$METRICS_PORT
done
