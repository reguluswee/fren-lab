const { deploy } = require("truffle-contract/lib/execute");

const StakeImpl = artifacts.require("StakeImpl");
const StakeProxy = artifacts.require("StakeProxy");
const StakeManager = artifacts.require("StakeManager");

module.exports = async function (deployer) {
  
  await deployer.deploy(StakeImpl).then((instance)=> {
  });
  console.log('StakeImpl deploy succeed:', StakeImpl.address)

  let adminIns;
  await deployer.deploy(StakeManager).then((instance) => {
    adminIns = instance
  })

  let deployProxyIns = null;
  await deployer.deploy(StakeProxy, StakeImpl.address, "0x").then((instance) => {
    deployProxyIns = instance;
  })

  await deployProxyIns.changeAdmin(StakeManager.address).then(result => {
    console.log('update admin', result.tx, result.receipt.status)
  })

  await adminIns.configCall(StakeProxy.address, "0x8129fc1c").then(result => {
    console.log('initialize', result.tx, result.receipt.status)
  })

};