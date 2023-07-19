const { deploy } = require("truffle-contract/lib/execute");

const LockManager = artifacts.require("LockManager");
const LockFancy = artifacts.require("LockFancy");

const DeployedLogicContract = '0x962DD412d943986737a82c4588210AEACBA5CB58'
const DeployedAdminContract = '0xC4EB878aF1229544F11A7c404da50dcC136D0b23'
const DeployedProxyContract = '0xCe2C4e2F81328F1ae2134D029cdEDfAAcBCD6727'


const needUpdate = true

module.exports = async function (deployer) {
  let deployedMinter = null;

  if(needUpdate) {
    console.log("deploying new contract")
    await deployer.deploy(LockFancy).then((instance)=> {
      deployedMinter = instance;
    });
  } else {
    console.log("loading pre contract")
    await LockFancy.at(DeployedLogicContract).then((instance) => {
      deployedMinter = instance
    })
  }
  console.log('LockFancy match succeed:', LockFancy.address)

  let adminContract = null;
  await LockManager.at(DeployedAdminContract).then(adminIns => {
    adminContract = adminIns
  })

  await adminContract.upgrade(DeployedProxyContract, LockFancy.address).then(v => {
    console.log('updated by admin', v)
  })
};