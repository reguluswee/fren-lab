const FopForHolder = artifacts.require("FopForHolder");


module.exports = async function (deployer) {

  await deployer.deploy(FopForHolder);
  console.log('New FopForHolder Contract deploy succeed:', FopForHolder.address)

};