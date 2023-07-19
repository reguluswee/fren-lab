const Friend = artifacts.require("Friend");

module.exports = async function (deployer) {
  await deployer.deploy(Friend, "0xCebFBEbd937f8645AFFC444be052B0C4F30b5A4F");
};
