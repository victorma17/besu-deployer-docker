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

rm -rf config bootnode node* docker-compose.yaml

# Function to generate keys using Besu in Docker
generate_keys() {
  node_dir=$1
  echo "Generating keys for $node_dir..."
  docker run --rm -v $PWD/config:/opt/besu/config -v $PWD/$node_dir/data:/opt/besu/data hyperledger/besu:24.6.0 operator generate-blockchain-config --config-file=/opt/besu/config/qbftConfigFile.json --to=/opt/besu/data --private-key-file-name=key

  first_folder=$(ls $PWD/$node_dir/data/keys | head -n 1)
  if [ -d "$PWD/$node_dir/data/keys/$first_folder" ]; then
    mv $PWD/$node_dir/data/keys/$first_folder/* $PWD/$node_dir/data
    rm -r $PWD/$node_dir/data/keys
    echo "Keys generated for $node_dir."

    if [[ $node_dir == "bootnode" ]]; then
      # Extract the node ID from the public key by removing '0x' prefix
      node_id=$(cat $PWD/$node_dir/data/key.pub | sed 's/^0x//')
      echo "Node ID for $node_dir: $node_id"
      echo $node_id >$PWD/config/bootnode_id
      # Copy the genesis.json from the bootnode to a common location
      cp $PWD/$node_dir/data/genesis.json $PWD/config/
      echo "Removing genesis.json from $node_dir and moving to config folder"
    fi
    rm -rf $PWD/$node_dir/data/genesis.json
  else
    echo "Error: Key generation for $node_dir failed."
    exit 1
  fi
}

# Ask the user for the default configuration
default=""
advanced=""
chainId=2222
blockperiodseconds=2
num_nodes=4
ip="172.16.240"
while [[ $default != "y" && $default != "n" ]]; do
  read -p "Do you want to CHANGE THE DEFAULT configuration (4 nodes, 172.16.240.0, chainId 2222, 2 sec between blocks)? Please enter 'y' or 'n': " default
  if [[ $default != "y" && $default != "n" ]]; then
    echo "Please enter 'y' or 'n'."
  fi
done
jq --argjson chainId "$chainId" '.genesis.config.chainId = $chainId' qbftConfigFile.json >temp.json && mv temp.json qbftConfigFile.json
jq --argjson blockperiodseconds "$blockperiodseconds" '.genesis.config.qbft.blockperiodseconds = $blockperiodseconds' qbftConfigFile.json >temp.json && mv temp.json qbftConfigFile.json

if [[ $default == "y" ]]; then
  chainId=0
  blockperiodseconds=0
  num_nodes=0
  while [[ $num_nodes -lt 4 || $num_nodes -gt 100 ]]; do
    read -p "Enter the number of nodes (including the bootnode, minimum 4): " num_nodes
    if [[ $num_nodes -lt 4 || $num_nodes -gt 100 ]]; then
      echo "You must create at least 4 nodes and maximum 100. Please try again."
    fi
  done
  while [[ $chainId -lt 1 ]]; do
    read -p "Enter the chain ID (e.g. 1234): " chainId
    if [[ $chainId -lt 1 ]]; then
      echo "You must enter a valid chain ID. Please try again."
    fi
  done
  jq --argjson chainId "$chainId" '.genesis.config.chainId = $chainId' qbftConfigFile.json >temp.json && mv temp.json qbftConfigFile.json
  while [[ $blockperiodseconds -lt 1 || $blockperiodseconds -gt 30 ]]; do
    read -p "Enter the block period in seconds (between 2 - 30): " blockperiodseconds
    if [[ $blockperiodseconds -lt 2 || $blockperiodseconds -gt 30 ]]; then
      echo "You must enter a block period in seconds within the interval. Please try again."
    fi
  done
  jq --argjson blockperiodseconds "$blockperiodseconds" '.genesis.config.qbft.blockperiodseconds = $blockperiodseconds' qbftConfigFile.json >temp.json && mv temp.json qbftConfigFile.json

  while [[ $advanced != "y" && $advanced != "n" ]]; do
    read -p "Do you want to CHANGE THE ADVANCE configuration (IP direction)? Please enter 'y' or 'n': " advanced
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

# Create a directory for config if it doesn't exist
echo "Setting up configuration..."
mkdir -p config
cp qbftConfigFile.json config/
echo "Configuration setup complete."

# Initial docker-compose.yaml content
cat >docker-compose.yaml <<EOF
version: "3.4"

networks:
  besu-network:
    driver: bridge
    ipam:
      config:
        - subnet: $ip.0/24

services:
EOF

# Loop to setup each node
echo "Setting up nodes..."
for ((i = 1; i <= num_nodes; i++)); do
  if [[ $i -eq 1 ]]; then
    node_dir="bootnode"
  else
    node_dir="node$((i - 1))"
  fi

  mkdir -p $node_dir/data
  generate_keys $node_dir

  if [[ $node_dir == "bootnode" ]]; then
    # Bootnode configuration
    cat >>docker-compose.yaml <<EOF
  $node_dir:
    container_name: $node_dir
    image: hyperledger/besu:24.6.0
    entrypoint:
      - /bin/bash
      - -c
      - |
        /opt/besu/bin/besu --data-path=/opt/besu/data \
        --genesis-file=/opt/besu/genesis.json --rpc-http-enabled \
        --host-allowlist="*" --rpc-http-cors-origins="all" \
        --tx-pool=sequenced \
        --tx-pool-limit-by-account-percentage=1 \
        --poa-block-txs-selection-max-time=100 \
        --rpc-http-api=ADMIN,DEBUG,WEB3,ETH,TXPOOL,CLIQUE,MINER,NET; 
    volumes:
      - ./config/bootnode_id:/opt/besu/config/bootnode_id
      - ./config/genesis.json:/opt/besu/genesis.json
      - ./$node_dir/data:/opt/besu/data
    ports:
      - 30303:30303
      - 8545:8545
    networks:
      besu-network:
        ipv4_address: $ip.30
EOF
  else
    # Other nodes configuration
    cat >>docker-compose.yaml <<EOF
  $node_dir:
    container_name: $node_dir
    image: hyperledger/besu:24.6.0
    entrypoint:
      - /bin/bash
      - -c
      - |
        sleep $((i * 1));
        /opt/besu/bin/besu --data-path=/opt/besu/data \
        --genesis-file=/opt/besu/genesis.json --rpc-http-enabled \
        --bootnodes=enode://\$(cat /opt/besu/config/bootnode_id)@$ip.30:30303 --p2p-port=30303 \
        --host-allowlist="*" --rpc-http-cors-origins="all" \
        --poa-block-txs-selection-max-time=100 \
        --tx-pool-limit-by-account-percentage=1 \
        --tx-pool=sequenced 
    volumes:
      - ./config/bootnode_id:/opt/besu/config/bootnode_id
      - ./config/genesis.json:/opt/besu/genesis.json
      - ./$node_dir/data:/opt/besu/data
    depends_on:
      - bootnode
    networks:
      besu-network:
        ipv4_address: $ip.$((30 + i - 1))
EOF
  fi
  echo "Node $node_dir setup complete."
done

echo "Setup Complete. Configuration files created."

# Start the network
docker-compose up
