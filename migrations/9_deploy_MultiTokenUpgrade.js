const { deploy } = require("truffle-contract/lib/execute");

const MultiAdmin = artifacts.require("MultiAdmin");
const MultiTokenMintV2 = artifacts.require("MultiTokenMintV2");

const DeployedProxyContract = '0x8e3f39Beb44758C004F856E1E7498bAB26CD3F3F'
const DeployedAdminContract = '0x02b9aFD26f9a25ac601DFd31A24C89d39B68eEcc'

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