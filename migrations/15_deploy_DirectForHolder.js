const DirectForHolder = artifacts.require("DirectForHolder");

const MerkleRoot = '0x6992957e4c13779db68692f254e866ee33afb0a49522f30819ceb6ec9befddde'

module.exports = async function (deployer) {

  await deployer.deploy(DirectForHolder, MerkleRoot);
  console.log('New DirectForHolder Contract deploy succeed:', DirectForHolder.address)

};