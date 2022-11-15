// const Treasury = artifacts.require("TreasuryOne");
const Treasury = artifacts.require("TreasuryTwo");

module.exports = async function (deployer) {
  await deployer.deploy(Treasury);
};
