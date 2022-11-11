const { deploy } = require("truffle-contract/lib/execute");

const BatchMint = artifacts.require("BatchMint");

const FRENOptionNFT = artifacts.require("FRENOptionNFT");
const FRENMinterNFT = artifacts.require("FRENMinterNFT");

module.exports = async function (deployer) {
  let deployedMinter = null;
  // should modify to $FREN coin contract address while mainneting
  await deployer.deploy(BatchMint, "0x7127deeff734cE589beaD9C4edEFFc39C9128771").then((instance)=> {
    deployedMinter = instance;
  });
  
  await deployer.deploy(FRENOptionNFT, BatchMint.address).then(() => {
  })

  console.log('NFT Contract deploy succeed and setting init parameters:', FRENOptionNFT.address)
  await deployedMinter.relayBatchParams('0x0000000000000000000000000000000000000000', FRENOptionNFT.address)

  let params = await deployedMinter.getBatchParams();
  console.log('NFT Contract parameters:', params)
};