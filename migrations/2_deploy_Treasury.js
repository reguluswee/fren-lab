const Treasury = artifacts.require("TreasuryOne");

module.exports = async function (deployer) {
  await deployer.deploy(Treasury);
};
