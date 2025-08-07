# Automatized Besu Docker Deployer and Parameterizable 🙌🏻

### Pre-Requisites

🟡 Docker and Docker-compose installed 

🟡 Docker running 


All that is needed is run the install shell script of configuration (Take a quick look before if you want to) 🙋🏻‍♂️

```bash
bash install.sh      
```

DONE 😎

For stop the network and clean the installation just run:
```bash
bash clean.sh      
```

### Customize more configuration

If you want to change the Genesis, you must to replace in 

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
 
### Troubleshooting

👀 1. Try to clean all your old files first

```bash
bash clean.sh      
```

👀 2. If you have some conflict with containers that are alredy under us, you can exec: (will drop any stopped container ⚠️)
```bash
docker container prune
docker network prune
```

If you want to see which validators contains the extradata field in genesis.json, set that fiel in a extradata.txt in your PWD ( just the 0x...)
```bash
besu rlp decode --from=extradata.txt --type=QBFT_EXTRA_DATA
```
