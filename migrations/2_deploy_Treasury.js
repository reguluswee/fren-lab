// const Treasury = artifacts.require("TreasuryOne");
const Treasury = artifacts.require("TreasuryThree");

module.exports = async function (deployer) {
  await deployer.deploy(Treasury);
};
