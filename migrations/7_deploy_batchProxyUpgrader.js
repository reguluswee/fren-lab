const { deploy } = require("truffle-contract/lib/execute");

const BatchProxy = artifacts.require("BatchProxy");
const BatchAdmin = artifacts.require("BatchAdmin");
const GeneralBatch_NEW = artifacts.require("GeneralBatch");

// const _batchAdmin_ = "0x52A119794b98cd15EE8b54Fd79A189051C5Fd6C6"
// const _batchProxy_ = "0xe00DB880eb886aeFF535f9BFb05d8BC7FA5b5C95"

const _deployedBatch_ = "0x08CA558eE24FEa269cFDee0630e843e32Fe8B54D"
const _batchAdmin_ = "0x36073Ed63Fb40DEF0e241445593d4F2a2eFA0E6C"
const _batchProxy_ = "0xBbaBAd9D18C957bfc127EF1C0D6661Ef5cdA4775"

const needUpdate = false

module.exports = async function (deployer) {
  let deployedMinter = null;
  
  if(needUpdate) {
    console.log("deploying new contract")
    await deployer.deploy(GeneralBatch_NEW).then((instance)=> {
      deployedMinter = instance;
    });
  } else {
    console.log("loading pre contract")
    await GeneralBatch_NEW.at(_deployedBatch_).then((instance) => {
      deployedMinter = instance
    })
  }
  console.log('GeneralBatch match succeed:', GeneralBatch_NEW.address)

  let adminContract = null;
  await BatchAdmin.at(_batchAdmin_).then(adminIns => {
    adminContract = adminIns
  })
  await adminContract.upgrade(_batchProxy_, GeneralBatch_NEW.address).then(v => {
    console.log('update to admin', v)
  })
};