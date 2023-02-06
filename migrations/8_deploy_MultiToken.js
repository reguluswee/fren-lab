const { deploy } = require("truffle-contract/lib/execute");

const MultiTokenMint = artifacts.require("MultiTokenMint");

module.exports = async function (deployer) {
  let deployedMinter = null;
  
  await deployer.deploy(MultiTokenMint).then((instance)=> {
    deployedMinter = instance;
  });
  console.log('MultiTokenMint deploy succeed:', MultiTokenMint.address)
};