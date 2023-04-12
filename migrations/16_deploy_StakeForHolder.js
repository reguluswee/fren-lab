const StakeForHolder = artifacts.require("StakeForHolder");

const MerkleRoot = '0xe54167473a256e987faa3761ebe1b7a993c0fd28fabf233987998e245f2b3c78'

module.exports = async function (deployer) {

  await deployer.deploy(StakeForHolder, MerkleRoot);
  console.log('New StakeForHolder Contract deploy succeed:', StakeForHolder.address)

};