const { deploy } = require("truffle-contract/lib/execute");

const BatchMintV2 = artifacts.require("BatchMintV2");
const FRENOptionNFTV2 = artifacts.require("FRENOptionNFTV2");

module.exports = async function (deployer) {
  let deployedMinter = null;
  // should modify to $FREN coin contract address while mainneting
  await deployer.deploy(BatchMintV2, "0x7127deeff734cE589beaD9C4edEFFc39C9128771").then((instance)=> {
    deployedMinter = instance;
  });
  console.log('BatchMintV2 deploy succeed:', BatchMintV2.address)

  await deployer.deploy(FRENOptionNFTV2, BatchMintV2.address).then(() => {
  })

  console.log('NFT Contract deploy succeed and setting init parameters:', FRENOptionNFTV2.address)
  await deployedMinter.relayBatchParams(FRENOptionNFTV2.address, 5, 0, 1)

  let params = await deployedMinter.getBatchParams();
  console.log('BatchMintV2 parameters:', params)
};