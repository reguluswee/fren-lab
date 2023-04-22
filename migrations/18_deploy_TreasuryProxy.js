const { deploy } = require("truffle-contract/lib/execute");

const TreasuryLogic = artifacts.require("TreasuryLogic");
const TreasuryProxy = artifacts.require("TreasuryProxy");
const TreasuryAdmin = artifacts.require("TreasuryAdmin");

module.exports = async function (deployer) {
  let deployedMinter = null;
  
  await deployer.deploy(TreasuryLogic).then((instance)=> {
    deployedMinter = instance;
  });
  console.log('TreasuryLogic deploy succeed:', TreasuryLogic.address)

  await deployer.deploy(TreasuryAdmin).then(() => {
  })

  let deployProxyIns = null;
  await deployer.deploy(TreasuryProxy, TreasuryLogic.address, "0x").then((instance) => {
    deployProxyIns = instance;
  })

  await deployProxyIns.changeAdmin(TreasuryAdmin.address).then(result => {
    console.log('update admin', result.tx, result.receipt.status)
  })
};