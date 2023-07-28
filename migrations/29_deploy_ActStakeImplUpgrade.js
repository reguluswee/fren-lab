const { deploy } = require("truffle-contract/lib/execute");

const StakeManager = artifacts.require("StakeManager");
const StakeImpl = artifacts.require("StakeImpl");

const DeployedLogicContract = '0x9c48E1C149cEa7643F4656170FC1B9cD8a089F05'

const DeployedAdminContract = '0x4AB6b3E9F46169754Df4183C43fbA076fC05ceE8'
const DeployedProxyContract = '0x3a6370B6C99a776833540f1eB884417604011a68'

const needUpdate = true

module.exports = async function (deployer) {
  let deployedMinter = null;

  if(needUpdate) {
    console.log("deploying new contract")
    await deployer.deploy(StakeImpl).then((instance)=> {
      deployedMinter = instance;
    });
  } else {
    console.log("loading pre contract")
    await StakeImpl.at(DeployedLogicContract).then((instance) => {
      deployedMinter = instance
    })
  }
  console.log('StakeImpl match succeed:', StakeImpl.address)

  let adminContract = null;
  await StakeManager.at(DeployedAdminContract).then(adminIns => {
    adminContract = adminIns
  })

  await adminContract.upgrade(DeployedProxyContract, StakeImpl.address).then(v => {
    console.log('updated by admin', v)
  })
};