// scripts/distribute_with_vesting.js
// Usage: npx hardhat run scripts/distribute_with_vesting.js --network bsctestnet
const { ethers } = require("hardhat");

function monthsToSeconds(m) {
  return BigInt(m) * 30n * 24n * 60n * 60n;
}

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  // ---------- CONFIG (REPLACE) ----------
  const tokenAddress = "0xPASTE_APM_TOKEN_ADDRESS";
  const vestingManagerAddress = "0xPASTE_VESTING_MANAGER_ADDRESS";

  // Allocation destination wallets (replace with real addresses / multisig / sale contract)
  const WALLETS = {
    publicSale: "0xPUBLIC_SALE_ADDRESS",
    teamBeneficiary: "0xTEAM_BENEFICIARY",
    treasury: "0xTREASURY_ADDRESS",
    partnerships: "0xPARTNERS_ADDRESS",
    ecosystem: "0xECOSYSTEM_ADDRESS",
    liquidity: "0xLIQUIDITY_ADDRESS"
  };

  // TGE timestamp (unix seconds) - set this to your planned TGE on mainnet
  // For testing, you can set to (Math.floor(Date.now()/1000) + 60)
  const TGE = Math.floor(Date.now() / 1000) + 60; // test: 60 seconds from now

  console.log("TGE (unix):", TGE);

  // ---------- INIT CONTRACTS ----------
  const Token = await ethers.getContractAt("APMToken", tokenAddress);
  const Vesting = await ethers.getContractAt("VestingManager", vestingManagerAddress);

  // Total supply (1,000,000,000 with 18 decimals)
  const TOTAL = ethers.parseUnits("1000000000", 18); // ethers v6 style
  // If using ethers v5: ethers.utils.parseUnits("1000000000", 18)

  // Percentages
  const P = {
    publicSale: 20,
    team: 12,
    treasury: 13,
    partnerships: 10,
    ecosystem: 35,
    liquidity: 10
  };

  // Helper to compute allocation amount (BigInt friendly)
  const compute = (pct) => TOTAL * BigInt(pct) / 100n;

  const amounts = {
    publicSale: compute(P.publicSale),
    team: compute(P.team),
    treasury: compute(P.treasury),
    partnerships: compute(P.partnerships),
    ecosystem: compute(P.ecosystem),
    liquidity: compute(P.liquidity)
  };

  console.log("Allocation amounts (human):");
  for (const k of Object.keys(amounts)) {
    console.log(`${k}:`, ethers.formatUnits(amounts[k], 18));
  }

  // ----------------- DISTRIBUTIONS -----------------

  // 1) Public Sale (immediate transfer)
  console.log("\n1) Transferring Public Sale allocation to:", WALLETS.publicSale);
  await (await Token.transfer(WALLETS.publicSale, amounts.publicSale)).wait();
  console.log(" -> done");

  // 2) Liquidity (transfer tokens for LP creation)
  console.log("\n2) Transferring Liquidity allocation to:", WALLETS.liquidity);
  await (await Token.transfer(WALLETS.liquidity, amounts.liquidity)).wait();
  console.log(" -> done");

  // 3) Treasury: immediate 10% at TGE + vest for remaining 90% over 36 months
  console.log("\n3) Treasury TGE unlock & vesting");
  const treasuryTGEUnlock = amounts.treasury * 10n / 100n; // 10%
  const treasuryRemaining = amounts.treasury - treasuryTGEUnlock;
  if (treasuryTGEUnlock > 0n) {
    console.log(" -> sending treasury TGE unlock:", ethers.formatUnits(treasuryTGEUnlock, 18));
    await (await Token.transfer(WALLETS.treasury, treasuryTGEUnlock)).wait();
  }
  // transfer remaining to VestingManager for scheduled release
  if (treasuryRemaining > 0n) {
    console.log(" -> funding VestingManager (treasury remaining):", ethers.formatUnits(treasuryRemaining, 18));
    await (await Token.transfer(vestingManagerAddress, treasuryRemaining)).wait();
    // create vesting: start = TGE, cliff = 0, duration = 36 months (in seconds)
    const treasuryCliff = 0;
    const treasuryDuration = monthsToSeconds(36);
    const tx = await Vesting.createVesting(WALLETS.treasury, treasuryRemaining, TGE, treasuryCliff, Number(treasuryDuration), false);
    const rc = await tx.wait();
    console.log(" -> Vesting created for treasury (txHash):", rc.transactionHash);
  }

  // 4) Team: 12 months cliff + 24 months linear -> total duration from TGE = 36 months
  console.log("\n4) Team vesting");
  // fund vesting manager
  await (await Token.transfer(vestingManagerAddress, amounts.team)).wait();
  const teamCliff = monthsToSeconds(12);
  const teamDuration = monthsToSeconds(36); // duration from TGE inclusive of cliff
  {
    const tx = await Vesting.createVesting(WALLETS.teamBeneficiary, amounts.team, TGE, Number(teamCliff), Number(teamDuration), false);
    const rc = await tx.wait();
    console.log(" -> Team vesting created (txHash):", rc.transactionHash);
  }

  // 5) Partnerships: 3 month cliff + 12 months linear -> we set duration=15 months from TGE
  console.log("\n5) Partnerships vesting");
  await (await Token.transfer(vestingManagerAddress, amounts.partnerships)).wait();
  const partnersCliff = monthsToSeconds(3);
  const partnersDuration = monthsToSeconds(15);
  {
    const tx = await Vesting.createVesting(WALLETS.partnerships, amounts.partnerships, TGE, Number(partnersCliff), Number(partnersDuration), false);
    const rc = await tx.wait();
    console.log(" -> Partnerships vesting created (txHash):", rc.transactionHash);
  }

  // 6) Ecosystem incentives: 0 cliff, 48 months emission (we choose 48 months)
  console.log("\n6) Ecosystem vesting");
  await (await Token.transfer(vestingManagerAddress, amounts.ecosystem)).wait();
  const ecoCliff = 0;
  const ecoDuration = monthsToSeconds(48);
  {
    const tx = await Vesting.createVesting(WALLETS.ecosystem, amounts.ecosystem, TGE, Number(ecoCliff), Number(ecoDuration), false);
    const rc = await tx.wait();
    console.log(" -> Ecosystem vesting created (txHash):", rc.transactionHash);
  }

  console.log("\n✓ Distribution + vesting creation finished.");
  console.log("Check balances and vesting schedule on VestingManager.");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
