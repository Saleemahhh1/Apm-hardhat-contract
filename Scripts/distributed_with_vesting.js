// scripts/distribute_with_vesting.js
// Usage: npx hardhat run scripts/distribute_with_vesting.js --network bsctestnet
const { ethers } = require("hardhat");

function monthsToSeconds(m) {
  return BigInt(m) * 30n * 24n * 60n * 60n;
}

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  // ---------- CONFIG ----------
  const tokenAddress = "0xPASTE_APM_TOKEN_ADDRESS";
  const vestingManagerAddress = "0xPASTE_VESTING_MANAGER_ADDRESS";

  // Allocation wallets
  const WALLETS = {
    publicSale: deployer.address,       // temporary fallback
    teamBeneficiary: deployer.address,  // temporary fallback
    treasury: deployer.address,         // temporary fallback
    partnerships: ethers.constants.AddressZero, // placeholder until real wallet is known
    ecosystem: deployer.address,        // temporary fallback
    liquidity: deployer.address         // temporary fallback
  };

  // TGE timestamp (25 Feb 2026 11:30 UTC)
  const TGE = 1771971000; 
  console.log("TGE (unix):", TGE);

  // ---------- INIT CONTRACTS ----------
  const Token = await ethers.getContractAt("APMToken", tokenAddress);
  const Vesting = await ethers.getContractAt("VestingManager", vestingManagerAddress);

  // Total supply (1B tokens, 18 decimals)
  const TOTAL = ethers.parseUnits("1000000000", 18);

  // Percentages
  const P = {
    publicSale: 20,
    team: 12,
    treasury: 13,
    partnerships: 10,
    ecosystem: 35,
    liquidity: 10
  };

  const compute = (pct) => TOTAL * BigInt(pct) / 100n;

  const amounts = {
    publicSale: compute(P.publicSale),
    team: compute(P.team),
    treasury: compute(P.treasury),
    partnerships: compute(P.partnerships),
    ecosystem: compute(P.ecosystem),
    liquidity: compute(P.liquidity)
  };

  console.log("Allocation amounts:");
  for (const k of Object.keys(amounts)) {
    console.log(`${k}:`, ethers.formatUnits(amounts[k], 18));
  }

  // ----------------- DISTRIBUTIONS -----------------

  // 1) Public Sale - 100% unlocked at TGE
  console.log("\n1) Public Sale transfer:", WALLETS.publicSale);
  await (await Token.transfer(WALLETS.publicSale, amounts.publicSale)).wait();

  // 2) Liquidity - 100% unlocked at TGE
  console.log("\n2) Liquidity transfer:", WALLETS.liquidity);
  await (await Token.transfer(WALLETS.liquidity, amounts.liquidity)).wait();

  // 3) Treasury - 10% TGE, 90% vesting 6 months after 3-month cliff
  console.log("\n3) Treasury allocation");
  const treasuryTGE = amounts.treasury * 10n / 100n;
  const treasuryVesting = amounts.treasury - treasuryTGE;
  if (treasuryTGE > 0n) {
    await (await Token.transfer(WALLETS.treasury, treasuryTGE)).wait();
    console.log(" -> Treasury TGE unlock sent:", ethers.formatUnits(treasuryTGE, 18));
  }
  if (treasuryVesting > 0n) {
    await (await Token.transfer(vestingManagerAddress, treasuryVesting)).wait();
    await Vesting.createVesting(
      WALLETS.treasury,
      treasuryVesting,
      TGE,
      Number(monthsToSeconds(3)), // 3-month cliff
      Number(monthsToSeconds(6)), // 6-month vesting
      false
    );
    console.log(" -> Treasury vesting scheduled for remaining 90%");
  }

  // 4) Team - 3 months cliff + 6 months vesting
  console.log("\n4) Team vesting");
  await (await Token.transfer(vestingManagerAddress, amounts.team)).wait();
  await Vesting.createVesting(
    WALLETS.teamBeneficiary,
    amounts.team,
    TGE,
    Number(monthsToSeconds(3)),
    Number(monthsToSeconds(6)),
    false
  );

  // 5) Ecosystem incentives - 3 months cliff + 6 months vesting
  console.log("\n5) Ecosystem incentives vesting");
  await (await Token.transfer(vestingManagerAddress, amounts.ecosystem)).wait();
  await Vesting.createVesting(
    WALLETS.ecosystem,
    amounts.ecosystem,
    TGE,
    Number(monthsToSeconds(3)),
    Number(monthsToSeconds(6)),
    false
  );

  // 6) Partnerships - only create vesting if address known
  if (WALLETS.partnerships !== ethers.constants.AddressZero) {
    console.log("\n6) Partnerships vesting");
    await (await Token.transfer(vestingManagerAddress, amounts.partnerships)).wait();
    await Vesting.createVesting(
      WALLETS.partnerships,
      amounts.partnerships,
      TGE,
      Number(monthsToSeconds(3)),
      Number(monthsToSeconds(6)),
      false
    );
  } else {
    console.log("\n6) Partnerships vesting skipped (address unknown)");
  }

  console.log("\n✓ Distribution + vesting setup complete.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
