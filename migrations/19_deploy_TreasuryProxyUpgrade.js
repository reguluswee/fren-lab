const { deploy } = require("truffle-contract/lib/execute");

const TreasuryAdmin = artifacts.require("TreasuryAdmin");
const TreasuryLogic = artifacts.require("TreasuryLogic");

const DeployedProxyContract = '0x1be251511C54E4BE38059c25fAEB9d2848d5dBC6'
const DeployedAdminContract = '0x3A19Cb5E81eb21e21F1BA9d8bB4E66f30616f781'

const DeployedLogicContract = '0xAc65b3EA4a23c6c09FA87BA77f318a9b1B7464bA'

const needUpdate = true

module.exports = async function (deployer) {
  let deployedMinter = null;

  if(needUpdate) {
    console.log("deploying new contract")
    await deployer.deploy(TreasuryLogic).then((instance)=> {
      deployedMinter = instance;
    });
  } else {
    console.log("loading pre contract")
    await TreasuryLogic.at(DeployedLogicContract).then((instance) => {
      deployedMinter = instance
    })
  }
  console.log('TreasuryLogic match succeed:', TreasuryLogic.address)

  let adminContract = null;
  await TreasuryAdmin.at(DeployedAdminContract).then(adminIns => {
    adminContract = adminIns
  })
  await adminContract.upgrade(DeployedProxyContract, TreasuryLogic.address).then(v => {
    console.log('updated by admin', v)
  })
};