const { deploy } = require("truffle-contract/lib/execute");

const ReleaseFancy = artifacts.require("ReleaseFancy");
const ReleaseProxy = artifacts.require("ReleaseProxy");
const ReleaseManager = artifacts.require("ReleaseManager");

module.exports = async function (deployer) {
  
  await deployer.deploy(ReleaseFancy).then((instance)=> {
  });
  console.log('ReleaseFancy deploy succeed:', ReleaseFancy.address)

  let adminIns;
  await deployer.deploy(ReleaseManager).then((instance) => {
    adminIns = instance
  })

  let deployProxyIns = null;
  await deployer.deploy(ReleaseProxy, ReleaseFancy.address, "0x").then((instance) => {
    deployProxyIns = instance;
  })

  await deployProxyIns.changeAdmin(ReleaseManager.address).then(result => {
    console.log('update admin', result.tx, result.receipt.status)
  })

  await adminIns.configCall(ReleaseProxy.address, "0x8129fc1c").then(result => {
    console.log('initialize', result.tx, result.receipt.status)
  })

};