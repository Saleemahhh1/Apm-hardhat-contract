// scripts/deploy_market_factory.js
// Usage: npx hardhat run scripts/deploy_market_factory.js --network bsctestnet

const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with:", deployer.address);

  // ---------- CONFIG ----------
  // Replace these with actual deployed APMToken address and treasury address
  const APM_TOKEN_ADDRESS = "0xPASTE_YOUR_APM_TOKEN_ADDRESS";
  const TREASURY_ADDRESS = "0xPASTE_YOUR_TREASURY_ADDRESS";

  // ---------- DEPLOY ----------
  const Factory = await ethers.getContractFactory("MarketFactory");
  const factory = await Factory.deploy(APM_TOKEN_ADDRESS, TREASURY_ADDRESS);
  await factory.deployed();

  console.log("✅ MarketFactory deployed at:", factory.address);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
