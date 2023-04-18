const MiningForHolder = artifacts.require("MiningForHolder");

// const root = "0x000000000000000000000000000000000000000000000000000000000000000"
const root = "0xcda14a162a64a888a53950f01a6485d8dc30ad86bfde16d27fd3d9399695fa2c"

module.exports = async function (deployer) {

  await deployer.deploy(MiningForHolder, root);
  console.log('New MiningForHolder Contract deploy succeed:', MiningForHolder.address)

};