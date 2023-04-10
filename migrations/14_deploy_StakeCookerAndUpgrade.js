const StakeCooker = artifacts.require("StakeCooker");
const FRENCrypto = artifacts.require("FRENCrypto");

const DeployedFrenContract = '0xf81ed9cecFE069984690A30b64c9AAf5c0245C9F'

module.exports = async function (deployer) {

  await deployer.deploy(StakeCooker);
  console.log('New StakeCooker Contract deploy succeed:', StakeCooker.address)

  let frenInstance = null;
  await FRENCrypto.at(DeployedFrenContract).then(adminIns => {
    frenInstance = adminIns
  })

  await frenInstance.resetStakeCooker(StakeCooker.address).then(v => {
    console.log('updated by admin', v)
  })

};