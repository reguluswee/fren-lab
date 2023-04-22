const { deploy } = require("truffle-contract/lib/execute");

const MultiAdmin = artifacts.require("MultiAdmin");
const MultiTokenMintV2 = artifacts.require("MultiTokenMintV2");

const DeployedProxyContract = '0x928b35685BDa2458B937B479Fb763D78476bF472'

const DeployedAdminContract = '0xE378697BEFFDc158AB41fDa09F1c63e7dFD9c484'

const DeployedLogicContract = '0x895586F7598f8477dee91Eb01fB20b3d078e360a'
const needUpdate = false

module.exports = async function (deployer) {
  let deployedMinter = null;

  if(needUpdate) {
    console.log("deploying new contract")
    await deployer.deploy(MultiTokenMintV2).then((instance)=> {
      deployedMinter = instance;
    });
  } else {
    console.log("loading pre contract")
    await MultiTokenMintV2.at(DeployedLogicContract).then((instance) => {
      deployedMinter = instance
    })
  }
  console.log('MultiTokenMintV2 match succeed:', MultiTokenMintV2.address)

  let adminContract = null;
  await MultiAdmin.at(DeployedAdminContract).then(adminIns => {
    adminContract = adminIns
  })
  await adminContract.upgrade(DeployedProxyContract, MultiTokenMintV2.address).then(v => {
    console.log('updated by admin', v)
  })
};