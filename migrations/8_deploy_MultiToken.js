const { deploy } = require("truffle-contract/lib/execute");

const MultiTokenMint = artifacts.require("MultiTokenMintV2");
const MultiProxy = artifacts.require("MultiProxy");
const MultiAdmin = artifacts.require("MultiAdmin");

module.exports = async function (deployer) {
  let deployedMinter = null;
  
  await deployer.deploy(MultiTokenMint).then((instance)=> {
    deployedMinter = instance;
  });
  console.log('MultiTokenMint deploy succeed:', MultiTokenMint.address)

  await deployer.deploy(MultiAdmin).then(() => {
  })

  let deployProxyIns = null;
  await deployer.deploy(MultiProxy, MultiTokenMint.address, "0x").then((instance) => {
    deployProxyIns = instance;
  })

  await deployProxyIns.changeAdmin(MultiAdmin.address).then(result => {
    console.log('update admin', result)
  })
};