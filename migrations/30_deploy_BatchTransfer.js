const BatchTransfer = artifacts.require("BatchTransfer");

var Web3 = require("web3")
var provider = new Web3.providers.HttpProvider("https://rpc.dischain.xyz")
var web3 = new Web3(provider)

module.exports = async function (deployer, network) {
  
  let frenEthf = "0x0000000000000000000000000000000000000000";
  let coinFee = web3.utils.toWei('0.1', "ether");
  let frenMinimum = web3.utils.toWei('10000000', "ether");
  let frenFee = web3.utils.toWei('880000', "ether");
  
  if(network == 'dis_mainnet') {
    // ETHF chain
    frenEthf = "0xf81ed9cecFE069984690A30b64c9AAf5c0245C9F";
    coinFee = web3.utils.toWei('0.1', "ether");
    frenMinimum = web3.utils.toWei('10000000', "ether");
    frenFee = web3.utils.toWei('880000', "ether");
  } else if(network == 'bsc_mainnet') {
    // BSC chain
    frenEthf = "0xE6A768464B042a6d029394dB1fdeF360Cb60bbEb";
    coinFee = web3.utils.toWei('0.01', "ether");
    frenMinimum = web3.utils.toWei('10000000', "ether");
    frenFee = web3.utils.toWei('880000', "ether");
  } else if(network == 'base_mainnet') {
    frenEthf = "0x0000000000000000000000000000000000000000";
    coinFee = web3.utils.toWei('0.001', "ether");
    frenMinimum = web3.utils.toWei('10000000', "ether");
    frenFee = web3.utils.toWei('880000', "ether");
  }
  console.log(frenEthf, network)

  // BSC chain
  // let frenEthf = "0xE6A768464B042a6d029394dB1fdeF360Cb60bbEb";
  // let coinFee = web3.utils.toWei('0.01', "ether");
  // let frenMinimum = web3.utils.toWei('10000000', "ether");
  // let frenFee = web3.utils.toWei('880000', "ether");

  await deployer.deploy(BatchTransfer, frenEthf, coinFee, frenMinimum, frenFee);
};
