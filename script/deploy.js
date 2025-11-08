const hre = require("hardhat");
const fs = require("fs");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  const Token = await hre.ethers.getContractFactory("APMToken");
  const token = await Token.deploy(1000000);
  await token.waitForDeployment();
  console.log("APM Token deployed to:", await token.getAddress());

  const Factory = await hre.ethers.getContractFactory("MarketFactory");
  const factory = await Factory.deploy(await token.getAddress());
  await factory.waitForDeployment();
  console.log("MarketFactory deployed to:", await factory.getAddress());

  fs.writeFileSync("./contracts/factoryAddress.json", JSON.stringify({ address: await factory.getAddress() }, null, 2));
  fs.writeFileSync("./contracts/tokenAddress.json", JSON.stringify({ address: await token.getAddress() }, null, 2));

  console.log("✅ Deployment completed successfully.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
