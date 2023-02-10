const { deploy } = require("truffle-contract/lib/execute");

const MultiAdmin = artifacts.require("MultiAdmin");
const MultiTokenMintV2 = artifacts.require("MultiTokenMintV2");

const DeployedProxyContract = '0x3fCAD63e7A33d55BFe0d0a98F49229D82D62e38d'
const DeployedAdminContract = '0x61549eEdE0d97399cF3F817CfdA784B9F54A7Eb3'

module.exports = async function (deployer) {
  let deployedMinter = null;
  
  await deployer.deploy(MultiTokenMintV2).then((instance)=> {
    deployedMinter = instance;
  });
  console.log('New Logic Contract deploy succeed:', MultiTokenMintV2.address)

  let adminContract = null;
  await MultiAdmin.at(DeployedAdminContract).then(adminIns => {
    adminContract = adminIns
  })
  await adminContract.upgrade(DeployedProxyContract, MultiTokenMintV2.address).then(v => {
    console.log('updated by admin', v)
  })
};