const { deploy } = require("truffle-contract/lib/execute");

const MultiAdmin = artifacts.require("MultiAdmin");
const MultiTokenMintV2 = artifacts.require("MultiTokenMintV2");

// const DeployedProxyContract = '0x8e3f39Beb44758C004F856E1E7498bAB26CD3F3F'
// const DeployedAdminContract = '0x02b9aFD26f9a25ac601DFd31A24C89d39B68eEcc'
// const DeployedLogicContract = "0x0000000000000000000000000000000000000000"

const DeployedProxyContract = '0x2283b492353Bbb955268812FfB200C724fc0Bd49'
const DeployedAdminContract = '0x4e7E4e720C4e98C86988bF71E03775BeB787F103'
const DeployedLogicContract = '0x1F0aA658fe7e37c1fC24a896b9e5D1ADdcaDa4Fc'
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