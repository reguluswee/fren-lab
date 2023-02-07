const { deploy } = require("truffle-contract/lib/execute");

const MultiAdmin = artifacts.require("MultiAdmin");
const MultiTokenMintV2 = artifacts.require("MultiTokenMintV2");

const DeployedProxyContract = '0xF713fB1fD9C78402c0b93F637409023C8Fc53879'
const DeployedAdminContract = '0xfba451d82686fC4a63a89455d2DDB0f674a45EdF'

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