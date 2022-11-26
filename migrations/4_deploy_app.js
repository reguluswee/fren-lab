const { deploy } = require("truffle-contract/lib/execute");

const MatchQuiz = artifacts.require("MatchQuiz");

let tokenContract = '0x7127deeff734cE589beaD9C4edEFFc39C9128771'; // ethf mainnet
// let tokenContract = '0xd849e23c4347Fe7e423f15F23C1b783C4FfdAb32'

module.exports = async function (deployer) {
  let deployedMinter = null;
  // should modify to $FREN coin contract address while mainneting
  await deployer.deploy(MatchQuiz, tokenContract).then((instance)=> {
    deployedMinter = instance;
    console.log('finish deployed match')
  });

};