const { deploy } = require("truffle-contract/lib/execute");

const LockFancy = artifacts.require("LockFancy");
const LockProxy = artifacts.require("LockProxy");
const LockManager = artifacts.require("LockManager");

module.exports = async function (deployer) {
  
  await deployer.deploy(LockFancy).then((instance)=> {
  });
  console.log('LockFancy deploy succeed:', LockFancy.address)

  let adminIns;
  await deployer.deploy(LockManager).then((instance) => {
    adminIns = instance
  })

  let deployProxyIns = null;
  await deployer.deploy(LockProxy, LockFancy.address, "0x").then((instance) => {
    deployProxyIns = instance;
  })

  await deployProxyIns.changeAdmin(LockManager.address).then(result => {
    console.log('update admin', result.tx, result.receipt.status)
  })

  await adminIns.configCall(LockProxy.address, "0x8129fc1c").then(result => {
    console.log('initialize', result.tx, result.receipt.status)
  })

};