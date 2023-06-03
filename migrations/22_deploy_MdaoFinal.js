const MdaoFinal = artifacts.require("MdaoFinal");


module.exports = async function (deployer) {

  await deployer.deploy(MdaoFinal, "0x93dbd505fa141a8c63a0374ed374e1af65cd2c0985d07868b6a7259e1b3a29f8");
  console.log('New MdaoFinal Contract deploy succeed:', MdaoFinal.address)

};