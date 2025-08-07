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
echo "Cleaning up previous setup folders..."
docker-compose down -v 2>/dev/null
# rm -rf config bootnode node* docker-compose.yaml

# Ask the user for the default configuration
default=""
advanced=""
chainId=2222
blockperiodseconds=2
num_nodes=4
besuVersion="24.12.2"
ip="172.16.240"
while [[ $default != "y" && $default != "n" ]]; do
  read -p "Do you want to -- CHANGE THE DEFAULT --  (24.12.2 Besu version, 4 nodes, IP 172.16.240.0, chainId 2222, 2 sec between blocks)? Please enter 'y' or 'n': " default
  if [[ $default != "y" && $default != "n" ]]; then
    echo "Please enter 'y' or 'n'."
  fi
done
jq --argjson chainId "$chainId" '.genesis.config.chainId = $chainId' ./config/qbftConfigFile.json >temp.json && mv temp.json ./config/qbftConfigFile.json
jq --argjson blockperiodseconds "$blockperiodseconds" '.genesis.config.qbft.blockperiodseconds = $blockperiodseconds' ./config/qbftConfigFile.json >temp.json && mv temp.json ./config/qbftConfigFile.json

if [[ $default == "y" ]]; then
  chainId=0
  blockperiodseconds=0
  num_nodes=0
  besuVersion=""
  while [[ $num_nodes -lt 4 || $num_nodes -gt 100 ]]; do
    read -p "Enter the number of nodes (including the bootnode, minimum 4): " num_nodes
    # Quitar espacios y asegurarse que es un número entero
  #  num_nodes=$(echo "$input" | tr -d '[:space:]')
  # Validar que sea un número entero mayor o igual a 4 y menor o igual a 100
  if [[ "$num_nodes" =~ ^[0-9]+$ ]] && (( num_nodes >= 4 && num_nodes <= 100 )); then
    break
  elseecho "You must create at least 4 nodes and maximum 100. Please try again."
    fi
  done
  while [[ $chainId -lt 1 ]]; do
    read -p "Enter the chain ID (e.g. 1234): " chainId
    if [[ $chainId -lt 1 ]]; then
      echo "You must enter a valid chain ID. Please try again."
    fi
  done
  jq --argjson chainId "$chainId" '.genesis.config.chainId = $chainId' ./config/qbftConfigFile.json >temp.json && mv temp.json ./config/qbftConfigFile.json
  while [[ $blockperiodseconds -lt 1 || $blockperiodseconds -gt 30 ]]; do
    read -p "Enter the block period in seconds (between 2 - 30): " blockperiodseconds
    if [[ $blockperiodseconds -lt 2 || $blockperiodseconds -gt 30 ]]; then
      echo "You must enter a block period in seconds within the interval. Please try again."
    fi
  done
  jq --argjson blockperiodseconds "$blockperiodseconds" '.genesis.config.qbft.blockperiodseconds = $blockperiodseconds' ./config/qbftConfigFile.json >temp.json && mv temp.json ./config/qbftConfigFile.json
  while [[ ! $besuVersion =~ ^[0-9]{2}\.[0-9]{2}\.[0-9]+$ ]]; do
    read -p "Enter the version of Besu (format: 24.12.2): " besuVersion
    if [[ ! $besuVersion =~ ^[0-9]{2}\.[0-9]{2}\.[0-9]+$ ]]; then
      echo "Invalid version format. Please use format like 24.12.2"
    fi
  done

  while [[ $advanced != "y" && $advanced != "n" ]]; do
    read -p "Do you want to CHANGE THE ADVANCE CONFIGURATION (IP direction)? Please enter 'y' or 'n': " advanced
    if [[ $advanced != "y" && $advanced != "n" ]]; then
      echo "Please enter 'y' or 'n'."
    fi
  done

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


mkdir -p QBFT-Network
for ((i = 1; i <= num_nodes; i++)); do
  mkdir -p "QBFT-Network/Node-$i/data"
done

cd QBFT-Network

# Function to generate keys using Besu in Docker
besu operator generate-blockchain-config --config-file=../config/qbftConfigFile.json --to=networkFiles --private-key-file-name=key

cp networkFiles/genesis.json ../config/genesis.json

sh ../moveKeys.sh 

docker network inspect besu-network >/dev/null 2>&1 || docker network create --driver=bridge --subnet=172.16.240.0/24 besu-network

cd ..

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

echo "Waiting for the bootnode to start some seconds ..."
sleep 7

# Get the enode from the bootnode
sh getEnode.sh 172.16.240.30

# create nodes 
sh createValidatorNodes.sh $besuVersion $num_nodes

echo "Setup Complete. Besu network starting! 🚀"
