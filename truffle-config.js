const HDWalletProvider = require('@truffle/hdwallet-provider')
const dotenv = require("dotenv")

dotenv.config()
const infuraKey = process.env.INFURA_KEY || ''
const infuraSecret = process.env.INFURA_SECRET || ''
const liveNetworkPK = process.env.LIVE_PK || ''
const privateKey = [ liveNetworkPK ]
const privateAddress = process.env.LIVE_ADDRESS
const etherscanApiKey = process.env.ETHERS_SCAN_API_KEY || ''
const polygonApiKey = process.env.POLYGON_SCAN_API_KEY || ''
const bscApiKey = process.env.BSC_SCAN_API_KEY || ''

/* just for treasury deploy and manage */
const updateDeployerPK = process.env.NEW_DEPLOYER_PK || ''
const updatePrivateKey = [updateDeployerPK]
const updatePrivateAddress = process.env.NEW_DEPLOYER_ADDRESS
/* just for treasury deploy and manage */

/* just for mintfun */
const mintfunDeployerPK = process.env.MINTFUN_DEPLOYER_PK || ''
const mfPrivateKey = [mintfunDeployerPK]
const mfPrivateAddress = process.env.MINTFUN_DEPLOYER_ADDRESS
/* just for mintfun */

/* polygon testnet */
const polygonDeployerPK = process.env.POLYGON_TEST_PK || ''
const polygonPrivateKey = [polygonDeployerPK]
const polygonPrivateAddress = process.env.POLYGON_TEST_ADDRESS
/* polygon testnet */

/* base */
const liveNetworkPKBase = process.env.BASE_PK || ''
const privateKeyBase = [ liveNetworkPKBase ]
const privateAddressBase = process.env.BASE_ADDRESS


module.exports = {
  networks: {
    ganache: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "5777",
      websocket: true
    },
    rinkeby: {
      provider: () => new HDWalletProvider({
        privateKeys: privKeysRinkeby,
        //providerOrUrl: `https://:${infuraSecret}@rinkeby.infura.io/v3/${infuraKey}`,
        providerOrUrl: `wss://:${infuraSecret}@rinkeby.infura.io/ws/v3/${infuraKey}`,
        pollingInterval: 56000
      }),
      network_id: 4,
      confirmations: 2,
      timeoutBlocks: 100,
      skipDryRun: true,
      from: privateAddress,
      networkCheckTimeout: 999999
    },
    goerli: {
      provider: () => new HDWalletProvider({
        privateKeys: privateKey,
        //providerOrUrl: `https://:${infuraSecret}@goerli.infura.io/v3/${infuraKey}`,
        providerOrUrl: `wss://:${infuraSecret}@goerli.infura.io/ws/v3/${infuraKey}`,
        pollingInterval: 56000
      }),
      network_id: 5,
      confirmations: 2,
      timeoutBlocks: 100,
      skipDryRun: true,
      from: privateAddress,
      networkCheckTimeout: 999999
    },
    bsc_testnet: {
      provider: () => new HDWalletProvider({
        privateKeys: privateKey,
        providerOrUrl: `https://data-seed-prebsc-1-s1.binance.org:8545`,
        pollingInterval: 56000
      }),
      network_id: 97,
      confirmations: 2,
      timeoutBlocks: 100,
      from: privateAddress,
      skipDryRun: true,
      networkCheckTimeout: 999999
    },
    pulsechain_testnet: {
      provider: () => new HDWalletProvider({
        privateKeys: privateKey,
        providerOrUrl: `https://rpc.v2b.testnet.pulsechain.com`,
        pollingInterval: 56000
      }),
      network_id: 941,
      confirmations: 2,
      timeoutBlocks: 100,
      skipDryRun: true,
      from: privateAddress,
      networkCheckTimeout: 999999
    },
    ethw_testnet: {
      provider: () => new HDWalletProvider({
        privateKeys: privateKey,
        providerOrUrl: `https://iceberg.ethereumpow.org/`,
        pollingInterval: 56000
      }),
      network_id: 10002,
      confirmations: 2,
      timeoutBlocks: 100,
      skipDryRun: true,
      from: privateAddress,
      networkCheckTimeout: 999999
    },
    mumbai: {
      provider: () => new HDWalletProvider({
        privateKeys: polygonPrivateKey,
        providerOrUrl: `https://rpc-mumbai.maticvigil.com/v1/53a113316e0a9e20bcf02b13dd504ac33aeea3ba`,
        pollingInterval: 56000
      }),
      network_id: 80001,
      confirmations: 2,
      timeoutBlocks: 200,
      pollingInterval: 1000,
      skipDryRun: true,
      from: polygonPrivateAddress,
      networkCheckTimeout: 999999
      //websockets: true
    },
    ethf_mainnet: {
      provider: () => new HDWalletProvider({
        //privateKeys: updatePrivateKey,
        privateKeys: privateKey,
        providerOrUrl: `https://rpc.etherfair.link`,//`http://221.218.208.94:18545`,//`https://rpc.etherfair.link`, //`https://rpc1.etherfair.org`,
        pollingInterval: 56000
      }),
      network_id: 513100,
      confirmations: 2,
      timeoutBlocks: 100,
      skipDryRun: true,
      // from: updatePrivateAddress,
      from: privateAddress,
      networkCheckTimeout: 99999999
    },
    eth_mainnet: {
      provider: () => new HDWalletProvider({
        privateKeys: mfPrivateKey,
        providerOrUrl: `https://mainnet.infura.io/v3/db7ad163cfed48c181c8456f2ab3fe54`,
        pollingInterval: 56000
      }),
      network_id: 1,
      confirmations: 2,
      timeoutBlocks: 100,
      skipDryRun: true,
      from: mfPrivateAddress,
      networkCheckTimeout: 999999
    },
    bsc_mainnet: {
      provider: () => new HDWalletProvider({
        privateKeys: privateKey,
        providerOrUrl: `https://bsc-dataseed1.ninicoin.io`,
        pollingInterval: 56000
      }),
      network_id: 56,
      confirmations: 2,
      timeoutBlocks: 100,
      skipDryRun: true,
      from: privateAddress,
      networkCheckTimeout: 999999
    },
    base_mainnet: {
      provider: () => new HDWalletProvider({
        privateKeys: privateKeyBase,
        providerOrUrl: `https://mainnet.base.org`,
        pollingInterval: 56000
      }),
      network_id: 8453,
      confirmations: 2,
      timeoutBlocks: 100,
      skipDryRun: true,
      from: privateAddressBase,
      networkCheckTimeout: 999999,
      gasPrice: 1000000000
    },
    dis_testnet: {
      provider: () => new HDWalletProvider({
        privateKeys: privateKey,
        providerOrUrl: `http://125.228.146.211`,//`http://221.218.208.94:18545`,//`https://rpc.etherfair.link`, //`https://rpc1.etherfair.org`,
        pollingInterval: 56000
      }),
      // network_id: 513111,
      network_id: 3,
      confirmations: 2,
      timeoutBlocks: 100,
      skipDryRun: true,
      from: privateAddress,
      networkCheckTimeout: 99999999
    }
  },
  mocha: {
    timeout: 100_000
  },
  compilers: {
    solc: {
      version: "0.8.17",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
        evmVersion: "london"
      }
    }
  },
  db: {
    enabled: false
  },
  plugins: ['truffle-plugin-verify'],
  api_keys: {
    etherscan: etherscanApiKey,
    bscscan: bscApiKey,
    polygonscan: polygonApiKey
  }
};
