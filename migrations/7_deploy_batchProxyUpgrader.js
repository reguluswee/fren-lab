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
  await BatchAdmin.at("0x52A119794b98cd15EE8b54Fd79A189051C5Fd6C6").then(adminIns => {
    adminContract = adminIns
  })
  await adminContract.upgrade("0xe00DB880eb886aeFF535f9BFb05d8BC7FA5b5C95", GeneralBatch_NEW.address).then(v => {
    console.log('update to admin', v)
  })
};