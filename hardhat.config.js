require("@nomiclabs/hardhat-ethers");
require("dotenv").config();

module.exports = {
  solidity: "0.8.19",
  networks: {
    bscTestnet: {
      url: `https://data-seed-prebsc-1-s1.binance.org:8545/`,
      accounts: [process.env.DEPLOYER_KEY]
    },
    bscMainnet: {
      url: `https://bsc-dataseed.binance.org/`,
      accounts: [process.env.DEPLOYER_KEY]
    }
  }
};
