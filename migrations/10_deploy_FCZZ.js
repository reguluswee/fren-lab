const { deploy } = require("truffle-contract/lib/execute");

//0x7c8B0356450eaA35bC2834B1D90e2e96373Dc798
const FCZZ = artifacts.require("FCZZ");

module.exports = async function (deployer) {
  let deployedMinter = null;
  
  await deployer.deploy(FCZZ).then((instance)=> {
    deployedMinter = instance;
  });
  console.log('New Token Contract deploy succeed:', FCZZ.address)

  
};