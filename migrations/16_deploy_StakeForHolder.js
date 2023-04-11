const StakeForHolder = artifacts.require("StakeForHolder");

const MerkleRoot = '0xfc171fb7e301a6874f0a5d305dfdcb6e3d931a4e701f617c61a61cd7d3571e3c'

module.exports = async function (deployer) {

  await deployer.deploy(StakeForHolder, MerkleRoot);
  console.log('New StakeForHolder Contract deploy succeed:', StakeForHolder.address)

};