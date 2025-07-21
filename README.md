# Besu deployer automatized and Iterative 🙌🏻

### Pre-Requisites

🟡 Docker and Docker-compose installed 

🟡 Docker running 


First of all we gonna run the install shell script of configuration 🙋🏻‍♂️

```sh
sh install.sh      
```

### Extra

To access to the Node Console
```
geth attach http://localhost:8545
```
Where we can exec commands like
```
eth.chainId()
eth.blockNumber
eth.getTransactionFromBlock(555)
web3.eth.getBalance("0x<direccion_de_tu_cuenta>", (err, balance) => { console.log(balance); });
admin.peers
```

Also calls directly through curl like:
```
curl -X POST --data '{"jsonrpc":"2.0",curl -X POST --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0x<YourAccountAddress>", "latest"],"id":1}' http://0.0.0.0:8545
```
 
### Troubleshooting

👀 If you have some conflict with containers that are alredy under us, you can exec: (will drop any stopped container ⚠️)
```
docker container prune
docker network prune
```

To start / stop the containers manually
```
docker-compose up
docker-compose down
```

