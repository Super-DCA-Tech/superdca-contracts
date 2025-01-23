import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";
// This adds support for typescript paths mappings
// import "tsconfig-paths/register";

import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-web3";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-solhint";
// import "@openzeppelin/hardhat-upgrades";
import "hardhat-contract-sizer";
import "hardhat-gas-reporter";
import "@typechain/hardhat";
import "solidity-coverage";
require("hardhat-tracer");
require("@nomiclabs/hardhat-etherscan");

dotenv.config();

import * as tdly from "@tenderly/hardhat-tenderly";
tdly.setup();

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.13",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
    }
  },
  // // About the gas reporter options ---> https://github.com/cgewecke/eth-gas-reporter/blob/master/README.md
  // gasReporter: {
  //   currency: "USD",
  //   token: "MATIC",
  //   gasPriceApi:
  //     "https://api.polygonscan.com/api?module=proxy&action=eth_gasPrice",
  //   rst: true,      // Output with a reStructured text code-block directive
  //   rstTitle: true, // "Gas Usage",
  //   showTimeSpent: true,
  // },
  networks: {
    hardhat: {
      forking: {
        url: process.env.POLYGON_NODE_URL || "",
        accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
        enabled: true, 
        chainId: 137,
        blockNumber: 54778190
      },
    },
    // polygon: {
    //   url: process.env.POLYGON_NODE_URL,
    //   accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    //   // blockGasLimit: 20000000,
    //   // gasPrice: 300000000000,
    //   chainId: 137,
    // },
    optimism: {
      url: process.env.OPTIMISM_NODE_URL || "https://optimism.gateway.tenderly.co/5hjijQPV8rGo1MCbtVE1v9",
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    sepolia: {
      chainId: 11155111,
      url: process.env.SEPOLIA_NODE_URL || "https://sepolia.gateway.tenderly.co",
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    base_sepolia: {
      chainId: 84532,
      url: process.env.BASE_SEPOLIA_NODE_URL || "https://sepolia.base.org",
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    maticmum: {
      url: process.env.MUMBAI_NODE_URL || "https://rpc-mumbai.matic.today",
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
      blockGasLimit: 20000000,
    },
    localhost: {
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
      url: 'http://127.0.0.1:8545/'
    },
    tenderly: {
      chainId: Number(process.env.TENDERLY_NETWORK_ID),
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
      url: process.env.TENDERLY_NODE_URL,
    },
  },
  mocha: {
    timeout: 0,
  },
  etherscan: {
    apiKey: {
      // ... (keep existing apiKeys if any)
      base_sepolia: process.env.BASE_SCAN_API_KEY || '' // Add this line
    },
    customChains: [
      {
        network: "base_sepolia",
        chainId: 84532,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org"
        }
      }
    ]
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },
  tenderly: {
    username: process.env.TENDERLY_USERNAME, 
    project: process.env.TENDERLY_PROJECT,
    forkNetwork: process.env.TENDERLY_NETWORK_ID,
    privateVerification: false,
  },
  plugins: ["solidity-coverage"],
  namedAccounts: {
  }
};

export default config;
