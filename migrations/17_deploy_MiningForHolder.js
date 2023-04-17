const MiningForHolder = artifacts.require("MiningForHolder");

module.exports = async function (deployer) {

  await deployer.deploy(MiningForHolder, "0x000000000000000000000000000000000000000000000000000000000000000");
  console.log('New MiningForHolder Contract deploy succeed:', MiningForHolder.address)

};