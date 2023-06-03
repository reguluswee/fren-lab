const LightX = artifacts.require("LightX");


module.exports = async function (deployer) {

  await deployer.deploy(LightX);
  console.log('New LightX Contract deploy succeed:', LightX.address)

};