const { deploy } = require("truffle-contract/lib/execute");

const GeneralBatch = artifacts.require("GeneralBatch");
const BatchProxy = artifacts.require("BatchProxy");
const BatchAdmin = artifacts.require("BatchAdmin");

module.exports = async function (deployer) {
  let deployedMinter = null;
  
  await deployer.deploy(GeneralBatch).then((instance)=> {
    deployedMinter = instance;
  });
  console.log('GeneralBatch deploy succeed:', GeneralBatch.address)

  await deployer.deploy(BatchAdmin).then(() => {
  })

  let deployProxyIns = null;
  await deployer.deploy(BatchProxy, GeneralBatch.address, "0x").then((instance) => {
    deployProxyIns = instance;
  })

  await deployProxyIns.changeAdmin(BatchAdmin.address).then(result => {
    console.log('update admin', result)
  })

  // console.log('NFT Contract deploy succeed and setting init parameters:', FRENOptionNFTV2.address)
  // await deployedMinter.relayBatchParams(FRENOptionNFTV2.address, 5, 0, 1)

  // let params = await deployedMinter.getBatchParams();
  // console.log('BatchMintV2 parameters:', params)
};