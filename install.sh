#!/bin/bash

# Check if Docker is installed and running
if ! command -v docker &>/dev/null; then
  echo "Docker could not be found. Please install Docker and try again."
  exit 1
fi
if ! docker info &>/dev/null; then
  echo "Docker is not running. Please start Docker and try again."
  exit 1
fi
echo "Docker is installed and running."

# Clean up previous setup and containers
echo "Cleaning up previous setup folders..."
docker-compose down -v 2>/dev/null
# rm -rf config bootnode node* docker-compose.yaml

# Default configuration parameters
default=""
advanced=""
chainId=2222
blockperiodseconds=2
num_nodes=4
besuVersion="24.12.2"
ip="172.16.240"

# Ask user if they want to change the default configuration
while [[ $default != "y" && $default != "n" ]]; do
  read -p "Do you want to -- CHANGE THE DEFAULT --  (24.12.2 Besu version, 4 nodes, IP 172.16.240.0, chainId 2222, 2 sec between blocks)? Please enter 'y' or 'n': " default
  if [[ $default != "y" && $default != "n" ]]; then
    echo "Please enter 'y' or 'n'."
  fi
done

# Update genesis file with default chainId and block period
jq --argjson chainId "$chainId" '.genesis.config.chainId = $chainId' ./config/qbftConfigFile.json >temp.json && mv temp.json ./config/qbftConfigFile.json
jq --argjson blockperiodseconds "$blockperiodseconds" '.genesis.config.qbft.blockperiodseconds = $blockperiodseconds' ./config/qbftConfigFile.json >temp.json && mv temp.json ./config/qbftConfigFile.json
jq --argjson count "$num_nodes" '.blockchain.nodes.count = $count' ./config/qbftConfigFile.json > temp.json && mv temp.json ./config/qbftConfigFile.json


# If custom configuration is selected
if [[ $default == "y" ]]; then
  chainId=0
  blockperiodseconds=0
  num_nodes=0
  besuVersion=""

  # Prompt user for number of nodes
  while [[ $num_nodes -lt 4 || $num_nodes -gt 100 ]]; do
    read -p "Enter the number of nodes (including the bootnode, minimum 4): " num_nodes
    if [[ "$num_nodes" =~ ^[0-9]+$ ]] && (( num_nodes >= 4 && num_nodes <= 100 )); then
      break
    else
      echo "You must create at least 4 nodes and maximum 100. Please try again."
    fi
  done
  jq --argjson count "$num_nodes" '.blockchain.nodes.count = $count' ./config/qbftConfigFile.json > temp.json && mv temp.json ./config/qbftConfigFile.json

  # Prompt user for chain ID
  while [[ $chainId -lt 1 ]]; do
    read -p "Enter the chain ID (e.g. 1234): " chainId
    if [[ $chainId -lt 1 ]]; then
      echo "You must enter a valid chain ID. Please try again."
    fi
  done

  # Update genesis file with custom chain ID
  jq --argjson chainId "$chainId" '.genesis.config.chainId = $chainId' ./config/qbftConfigFile.json >temp.json && mv temp.json ./config/qbftConfigFile.json

  # Prompt user for block period
  while [[ $blockperiodseconds -lt 1 || $blockperiodseconds -gt 30 ]]; do
    read -p "Enter the block period in seconds (between 2 - 30): " blockperiodseconds
    if [[ $blockperiodseconds -lt 2 || $blockperiodseconds -gt 30 ]]; then
      echo "You must enter a block period in seconds within the interval. Please try again."
    fi
  done

  # Update genesis file with custom block period
  jq --argjson blockperiodseconds "$blockperiodseconds" '.genesis.config.qbft.blockperiodseconds = $blockperiodseconds' ./config/qbftConfigFile.json >temp.json && mv temp.json ./config/qbftConfigFile.json

  # Prompt user for Besu version
  while [[ ! $besuVersion =~ ^[0-9]{2}\.[0-9]{2}\.[0-9]+$ ]]; do
    read -p "Enter the version of Besu (format: 24.12.2): " besuVersion
    if [[ ! $besuVersion =~ ^[0-9]{2}\.[0-9]{2}\.[0-9]+$ ]]; then
      echo "Invalid version format. Please use format like 24.12.2"
    fi
  done

  # Ask user if they want to change the network IP configuration
  while [[ $advanced != "y" && $advanced != "n" ]]; do
    read -p "Do you want to CHANGE THE ADVANCE CONFIGURATION (IP direction)? Please enter 'y' or 'n': " advanced
    if [[ $advanced != "y" && $advanced != "n" ]]; then
      echo "Please enter 'y' or 'n'."
    fi
  done

  # If advanced network IP configuration is enabled
  if [[ $advanced == "y" ]]; then
    ip=""
    while [[ $ip == "" ]]; do
      read -p "Enter the IP address mask (first 3 numbers, e.g. 172.16.240): " ip
      if [[ ! $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "You must enter a valid IP address mask. Please try again."
        ip=""
      fi
    done
  fi
fi

# Create directory structure for validator nodes
mkdir -p QBFT-Network
for ((i = 1; i <= num_nodes; i++)); do
  mkdir -p "QBFT-Network/Node-$i/data"
done

cd QBFT-Network

# Generate genesis and validator keys using Besu
# besu operator generate-blockchain-config 
# --config-file=../config/qbftConfigFile.json 
# --to=networkFiles 
# --private-key-file-name=key
docker run --rm \
  -v "$(pwd)/../config:/opt/besu/config" \
  -v "$(pwd):/opt/besu/output" \
  hyperledger/besu:$besuVersion \
  operator generate-blockchain-config \
  --config-file=/opt/besu/config/qbftConfigFile.json \
  --to=/opt/besu/output/networkFiles \
  --private-key-file-name=key 2>/dev/null


# Copy the generated genesis to the config folder
cp networkFiles/genesis.json ../config/genesis.json

# Move the generated validator keys to each node's data folder
sh ../moveKeys.sh 

# Create the custom Docker network if not already created
docker network inspect besu-network >/dev/null 2>&1 || docker network create --driver=bridge --subnet=172.16.240.0/24 besu-network

cd ..

# Start the bootnode container
docker run -d --name bootnode \
  -v "$(pwd)/config:/opt/besu/config" \
  -v "$(pwd)/QBFT-Network/Node-1/data:/opt/besu/data" \
  -p 30303:30303 \
  -p 8545:8545 \
  -p 9545:9545 \
  --label project=besu \
  --network besu-network \
  --ip 172.16.240.30 \
  hyperledger/besu:$besuVersion \
  --config-file=/opt/besu/config/configBootnode.toml

# Wait for the bootnode to be ready
echo "Waiting for the bootnode to start some seconds ..."
sleep 7

# Fetch the bootnode enode and insert it into the validator config
sh getEnode.sh 172.16.240.30

# Launch all validator node containers
sh createValidatorNodes.sh $besuVersion $num_nodes

# Finish
echo "Setup Complete. Besu network starting! 🚀"
