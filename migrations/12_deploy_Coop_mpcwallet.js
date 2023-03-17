const { deploy } = require("truffle-contract/lib/execute");

const MpcWallet = artifacts.require("MpcWallet");

module.exports = async function (deployer) {
  await deployer.deploy(MpcWallet, "0x0709f50ada83de79cc9cd8c19df3285ab6eb0159c4699073d3a915f1c1843b92").then((instance)=> {
    console.log('MpcWallet deploy succeed:', instance)
  });
  
};