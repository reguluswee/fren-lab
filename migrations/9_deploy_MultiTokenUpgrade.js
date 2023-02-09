const { deploy } = require("truffle-contract/lib/execute");

const MultiAdmin = artifacts.require("MultiAdmin");
const MultiTokenMintV2 = artifacts.require("MultiTokenMintV2");

const DeployedProxyContract = '0x119B1bbCBe1382149adA92d8969fa660654d9C35'
const DeployedAdminContract = '0x7db8d022Cd11d8A358E0F46946942B3F86bFD9B7'

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