// const Treasury = artifacts.require("TreasuryOne");
//const Treasury = artifacts.require("TreasuryThree"); 0xcCa5db687393a018d744658524B6C14dC251015f

const BatchTransfer = artifacts.require("BatchTransfer");

module.exports = async function (deployer) {
  await deployer.deploy(BatchTransfer);
};
