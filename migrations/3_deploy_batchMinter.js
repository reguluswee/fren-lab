const { deploy } = require("truffle-contract/lib/execute");

const BatchMint = artifacts.require("BatchMint");

module.exports = async function (deployer) {
  let deployedMinter = null;
  // should modify to $FREN coin contract address while mainneting
  await deployer.deploy(BatchMint, "0x7127deeff734cE589beaD9C4edEFFc39C9128771").then((instance)=> {
    deployedMinter = instance;
  });

  await deployedMinter.relayBatchParams(5, '0xa5E5e2506392B8467A4f75b6308a79c181Ab9fbF')

  let params = await deployedMinter.getBatchParams();
  console.log('NFT Contract parameters:', params)
};