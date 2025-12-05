// scripts/deploy-vesting.js
const { ethers } = require("hardhat");

function months(m) {
  return m * 30 * 24 * 60 * 60; // approximate month
}

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  // 1) Deploy token
  const Token = await ethers.getContractFactory("APMToken");
  const token = await Token.deploy();
  await token.deployed();
  console.log("APMToken deployed:", token.address);

  // 2) Deploy VestingManager (token must be funded later)
  const Vesting = await ethers.getContractFactory("VestingManager");
  const vesting = await Vesting.deploy(token.address);
  await vesting.deployed();
  console.log("VestingManager deployed:", vesting.address);

  // Addresses (replace with real addresses / multisig)
  const publicSaleAddr = "0xPUBLICSALEADDRESS000000000000000000000000";
  const liquidityAddr  = "0xLIQUIDITYADDRESS000000000000000000000000";
  const treasuryAddr   = "0xTREASURYADDRESS0000000000000000000000000";
  const partnersAddr   = "0xPARTNERSADDRESS000000000000000000000000";
  const ecosystemAddr  = "0xECOSYSTEMADDRESS000000000000000000000000";
  const teamAddr       = "0xTEAMADDRESS0000000000000000000000000000000";
  const marketTreasury = treasuryAddr; // used by MarketFactory as treasury

  // Utility: helper to compute pct
  const decimals = ethers.BigNumber.from("1000000000000000000"); // 1e18
  const totalSupply = ethers.BigNumber.from("1000000000").mul(decimals); // 1B * 1e18

  const pct = (p) => totalSupply.mul(p).div(100);

  const publicAmt = pct(20);
  const teamAmt = pct(12);
  const treasuryAmt = pct(13);
  const partnersAmt = pct(10);
  const ecosystemAmt = pct(35);
  const liquidityAmt = pct(10);

  // 3) Transfer immediate allocations:
  // a) Public sale (immediate)
  await token.transfer(publicSaleAddr, publicAmt);
  console.log("Public sale tokens transferred");

  // b) Liquidity (keep in liquidity address to create LP)
  await token.transfer(liquidityAddr, liquidityAmt);
  console.log("Liquidity tokens transferred");

  // 4) Fund VestingManager with team + treasury + partners + ecosystem
  const vestingTotal = teamAmt.add(treasuryAmt).add(partnersAmt).add(ecosystemAmt);
  await token.transfer(vesting.address, vestingTotal);
  console.log("VestingManager funded with:", ethers.utils.formatEther(vestingTotal));

  // 5) Create vesting schedules (all start at TGE)
  const now = Math.floor(Date.now() / 1000);
  const TGE = now + 60 * 60; // set TGE (replace with actual TGE timestamp for mainnet)

  // Team: 12m cliff + 24m vesting (we pass start=TGE, cliff=12m, duration=36m)
  const teamCliff = months(12);
  const teamDuration = months(36);
  const teamVestingId = await (await vesting.createVesting(teamAddr, teamAmt, TGE, teamCliff, teamDuration, false)).wait();
  console.log("Team vesting created");

  // Treasury: 10% at TGE (we already transferred to vesting contract); to model 10% immediate,
  // you could either transfer 10% to treasuryAddr directly (outside vesting), and vest remaining 90%.
  // Simpler: transfer 10% here directly:
  const treasuryImmediate = treasuryAmt.mul(10).div(100); // 10%
  await token.transfer(treasuryAddr, treasuryImmediate);
  const treasuryRemaining = treasuryAmt.sub(treasuryImmediate);
  // create vesting for remaining 90%: duration 36 months
  const treasuryVestingId = await (await vesting.createVesting(treasuryAddr, treasuryRemaining, TGE, 0, months(36), false)).wait();
  console.log("Treasury vesting created (90% in vesting)");

  // Partnerships: 3m cliff + 12m linear (we pass duration=15 months from TGE)
  await vesting.createVesting(partnersAddr, partnersAmt, TGE, months(3), months(15), false);
  console.log("Partners vesting created");

  // Ecosystem: 48 months emission
  await vesting.createVesting(ecosystemAddr, ecosystemAmt, TGE, 0, months(48), false);
  console.log("Ecosystem vesting created");

  // 6) Deploy MarketFactory
  const Factory = await ethers.getContractFactory("MarketFactory");
  const factory = await Factory.deploy(token.address, marketTreasury);
  await factory.deployed();
  console.log("MarketFactory deployed:", factory.address);

  // Final notes
  console.log("Deployment complete. PLEASE transfer ownership to multisig, lock LP tokens and set the real TGE timestamp before mainnet.");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
