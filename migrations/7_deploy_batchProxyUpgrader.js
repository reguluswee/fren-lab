const { deploy } = require("truffle-contract/lib/execute");

const BatchProxy = artifacts.require("BatchProxy");
const BatchAdmin = artifacts.require("BatchAdmin");
const GeneralBatch_NEW = artifacts.require("GeneralBatchV2");

module.exports = async function (deployer) {
  let deployedMinter = null;
  
  await deployer.deploy(GeneralBatch_NEW).then((instance)=> {
    deployedMinter = instance;
  });
  console.log('GeneralBatch deploy succeed:', GeneralBatch_NEW.address)

  let adminContract = null;
  await BatchAdmin.at("0xA68a1E5BbF1b4071899BF6bb4cB126dBc48Bc1C7").then(adminIns => {
    adminContract = adminIns
  })
  await adminContract.upgrade("0xDD153F0C2c70A64A82e693d5329D244D25886afD", GeneralBatch_NEW.address).then(v => {
    console.log('update to admin', v)
  })
  // BatchProxy.at("0x413f201c24f6A4DCad9E7143D1eff6bc97CAacc0").then((instance) => {
  //   console.log('准备升级合约')
  //   BatchAdmin.at("0x1B1c75298dD0917D5EfE86aDC2233A1CF99Ba8f4").then(adminIns => {
  //     adminIns.upgrade("0x413f201c24f6A4DCad9E7143D1eff6bc97CAacc0")
  //   })
  //   instance.upgradeTo(GeneralBatchV2.address)
  // })

  // let params = await deployedMinter.getBatchParams();
  // console.log('BatchMintV2 parameters:', params)
};