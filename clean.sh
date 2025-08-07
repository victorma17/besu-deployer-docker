#!/bin/bash

echo "Stopping and removing Docker containers using 'hyperledger/besu' image..."

docker ps -a --filter "label=project=besu" -q | xargs -r docker stop
docker ps -a --filter "label=project=besu" -q | xargs -r docker rm

echo "Deleting QBFT-Network directory..."
rm -rf QBFT-Network

echo "Deleting config/genesis.json..."
rm -f config/genesis.json

echo "Cleanup complete."
