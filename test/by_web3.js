
const { default: BigNumber } = require("bignumber.js")
var Web3 = require("web3")
const Tx = require('ethereumjs-tx').Transaction;

var _20abi = require("../build/contracts/XENCrypto.json")['abi']

var ownerKey = "**"

var chain_name = "EthereumFair"
var provider = new Web3.providers.HttpProvider("https://rpc.etherfair.org")

var web3 = new Web3(provider)
var gldtoken = new web3.eth.Contract(_20abi, "0x7127deeff734cE589beaD9C4edEFFc39C9128771", {
    from: 0,
    gasPrice: '21808007493'
})

async function getContractParams() {
    let burnRate = await gldtoken.methods.burnRate().call();
    let treasuryRate = await gldtoken.methods.treasuryRate().call();
    let communityWallet = await gldtoken.methods.communityWallet().call();
    console.log(burnRate, treasuryRate, communityWallet);
}


async function setMintValue(prikey) {
    const privateKey = Buffer.from(prikey, 'hex');

    const walletAccount = web3.eth.accounts.privateKeyToAccount(prikey);
    console.log("address: ",walletAccount.address)

    let nonce = await web3.eth.getTransactionCount(walletAccount.address)
    console.log('get nonce:', nonce)

    let bn = web3.utils.toBN(0.1*(10**18))
    console.log('bn=====', bn.toString())
    let data = await gldtoken.methods.relayMint(bn.toString()).encodeABI()
    console.log(data)

    const txParams = {
        from: walletAccount.address,
        nonce: web3.utils.toHex(nonce),
        gasLimit: web3.utils.toHex(500000), 
        gasPrice: web3.utils.toHex(web3.utils.toWei('10', 'gwei')),
        to: "0x7127deeff734cE589beaD9C4edEFFc39C9128771",
        data: data
    }
    const tx = new Tx(txParams, {'chain':chain_name})
    // const tx = new Tx(txParams)
    tx.sign(privateKey)

    const serializedTx = tx.serialize()
    const raw = '0x' + serializedTx.toString('hex')
    console.log(raw)
    web3.eth.sendSignedTransaction(raw)
        .on('transactionHash', function(hash) {
            console.log('tx hash:', hash)
        })
        .on('receipt', function(receipt) {
            console.log('tx receipt:', receipt)
        })
        .on('error', console.error)
}

async function setTreasuryWallet(prikey) {
    const privateKey = Buffer.from(prikey, 'hex');

    const walletAccount = web3.eth.accounts.privateKeyToAccount(prikey);
    console.log("address: ",walletAccount.address)

    let nonce = await web3.eth.getTransactionCount(walletAccount.address)
    console.log('get nonce:', nonce)

    let bn = web3.utils.toBN(0.002*(10**18))
    console.log('bn=====', bn.toString())
    let data = await gldtoken.methods.relayCommunityWallet("0xc1AD7d393CbAC5Ad59406d428Ae4E5AEFd00A04c").encodeABI()
    console.log(data)

    const txParams = {
        from: walletAccount.address,
        nonce: web3.utils.toHex(nonce),
        gasLimit: web3.utils.toHex(500000), 
        gasPrice: web3.utils.toHex(web3.utils.toWei('10', 'gwei')),
        to: "0x9f1B4F9c616a204589ccaA0EeD7709e739B9724C",
        data: data
    }
    const tx = new Tx(txParams, {'chain':chain_name})
    // const tx = new Tx(txParams)
    tx.sign(privateKey)

    const serializedTx = tx.serialize()
    const raw = '0x' + serializedTx.toString('hex')
    console.log(raw)
    web3.eth.sendSignedTransaction(raw)
        .on('transactionHash', function(hash) {
            console.log('tx hash:', hash)
        })
        .on('receipt', function(receipt) {
            console.log('tx receipt:', receipt)
        })
        .on('error', console.error)
}

async function setTreasuryRate(prikey, rate) {
    const privateKey = Buffer.from(prikey, 'hex');

    const walletAccount = web3.eth.accounts.privateKeyToAccount(prikey);
    console.log("address: ",walletAccount.address)

    let nonce = await web3.eth.getTransactionCount(walletAccount.address)
    console.log('get nonce:', nonce)


    let data = await gldtoken.methods.relayRate(0, rate).encodeABI()
    console.log(data)

    const txParams = {
        from: walletAccount.address,
        nonce: web3.utils.toHex(nonce),
        gasLimit: web3.utils.toHex(500000), 
        gasPrice: web3.utils.toHex(web3.utils.toWei('10', 'gwei')),
        to: "0x9f1B4F9c616a204589ccaA0EeD7709e739B9724C",
        data: data
    }
    const tx = new Tx(txParams, {'chain':chain_name})
    // const tx = new Tx(txParams)
    tx.sign(privateKey)

    const serializedTx = tx.serialize()
    const raw = '0x' + serializedTx.toString('hex')
    console.log(raw)
    web3.eth.sendSignedTransaction(raw)
        .on('transactionHash', function(hash) {
            console.log('tx hash:', hash)
        })
        .on('receipt', function(receipt) {
            console.log('tx receipt:', receipt)
        })
        .on('error', console.error)
}


setMintValue(ownerKey)
// getContractParams()
// setTreasuryWallet(ownerKey)
// setTreasuryRate(ownerKey, 60)