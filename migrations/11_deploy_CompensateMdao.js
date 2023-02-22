const { deploy } = require("truffle-contract/lib/execute");

const CompensateMdao = artifacts.require("CompensateMdao");
const Math = artifacts.require("Math");

module.exports = async function (deployer) {
  await deployer.deploy(Math);
  await deployer.link(Math, CompensateMdao);
  await deployer.deploy(CompensateMdao);
};