# Automatized Besu Docker Deployer and Parameterizable 🙌🏻

This project provides an automated, Docker-based deployment of a Hyperledger Besu QBFT network, allowing you to quickly spin up a configurable private blockchain without installing Besu locally. All configuration parameters—such as number of validators, Besu version, chain ID, block time, and network IP—can be set interactively or left at defaults, making it easy for both beginners and advanced users to deploy, test, and manage a Besu network entirely in Docker.

This tool is developed for Linux terminal, if you are running this in Windows under WSL, you will need to execute a cleaner tool that make scripts compatible first ($ dos2unix * config/*)

### Pre-Requisites

🟡 Docker and Docker-compose installed 

🟡 jq installed ($ brew install jq)

🟡 Docker running 


### DEPLOYMENT

To deploy and make it work, simply run the installation script (you may review it beforehand if you wish): 🙋🏻‍♂️

```bash
bash install.sh      
```

DONE 😎

To stop the network and clean the installation just run:
```bash
bash clean.sh      
```

### Customize more configuration

If you want to change the Genesis, you must replace in 

### Extra

🟡 First if you want access to the geth console you need to install first:
```bash
brew install geth
```

Then run the Node Console
```bash
geth attach http://localhost:8545
```
Where we can exec commands like
```bash
eth.chainId()
eth.blockNumber
eth.getTransactionFromBlock(555)
web3.eth.getBalance("0x<direccion_de_tu_cuenta>", (err, balance) => { console.log(balance); });
web3.version
admin.peers
exit
```

Also calls directly through curl like:
```bash
curl -X POST --data '{"jsonrpc":"2.0",curl -X POST --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0x<YourAccountAddress>", "latest"],"id":1}' http://0.0.0.0:8545
```
 
### 👀 Troubleshooting 👀

1. Try to clean all your old files first

```bash
bash clean.sh      
```

2. If you have some conflict with containers that are already under us, you can exec: (will drop any stopped container ⚠️)
```bash
docker container prune
docker network prune
```

3. If you want to see which validators contains the extradata field in genesis.json, set that fiel in a extradata.txt in your PWD (just the 0x in your file)
```bash
docker run --rm -v "$(pwd):/opt/besu/data" hyperledger/besu:24.12.2 rlp decode --from=/opt/besu/data/extradata.txt --type=QBFT_EXTRA_DATA
```
