const { deploy } = require("truffle-contract/lib/execute");

const LockManager = artifacts.require("LockManager");
const LockFancy = artifacts.require("LockFancy");

const DeployedLogicContract = '0xD5B2910bDA009c0D2A0820062CcaC2cB8fc4A7cF'
const DeployedAdminContract = '0x032A5aE910076488a63206e29A6e73eAda0239Cd'
const DeployedProxyContract = '0xCebFBEbd937f8645AFFC444be052B0C4F30b5A4F'

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