
var Web3 = require("web3")
var provider = new Web3.providers.HttpProvider("https://rpc.etherfair.org")
var web3 = new Web3(provider)

const FRENCrypto = artifacts.require("FRENCrypto");
const FrenCooker = artifacts.require("FrenCooker");
const Math = artifacts.require("Math");

const carryBlock = 16807817
const genesisTs = 1666077340
const carryGlobalRank = 1180918

const preMintAmount = web3.utils.toWei('5500000000000', "ether") //pre mint
const preMintHolder = '0x0926c669CC58E83Da4b9F97ceF30f508500732a6'

console.log('preMintAmount:', preMintAmount)

module.exports = async function (deployer) {
  await deployer.deploy(Math);
  await deployer.link(Math, FRENCrypto);

  let frenInstance = null;
  await deployer.deploy(FRENCrypto, carryGlobalRank, genesisTs, carryBlock, preMintAmount, preMintHolder).then((instance) => {
    deployProxyIns = instance;
  });

  await deployer.link(Math, FrenCooker);
  await deployer.deploy(FrenCooker, FRENCrypto.address)

  await frenInstance.relayCooker(FrenCooker.address).then(result => {
    console.log('update FrenCooker success', result)
  })

  await frenInstance.relayTreasury("0x73d24160cBE2145c68466cc8940fcd34f6614576").then(result => {
    console.log('update Treasury', result)
  })
  
};