const BatchTransfer = artifacts.require("BatchTransfer");

var Web3 = require("web3")
var provider = new Web3.providers.HttpProvider("https://rpc.etherfair.org")
var web3 = new Web3(provider)

module.exports = async function (deployer) {
  let frenEthf = "0xf81ed9cecFE069984690A30b64c9AAf5c0245C9F";
  let coinFee = web3.utils.toWei('0.1', "ether");
  let frenMinimum = web3.utils.toWei('10000000', "ether");
  let frenFee = web3.utils.toWei('880000', "ether");

  await deployer.deploy(BatchTransfer, frenEthf, coinFee, frenMinimum, frenFee);
};
