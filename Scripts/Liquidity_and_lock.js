// scripts/add_liquidity_and_lock.js
// Usage:
// 1) Send tokens to deployer or the address that will add liquidity (WALLET)
// 2) Ensure WALLET has BNB (testnet) for pairing
// 3) npx hardhat run scripts/add_liquidity_and_lock.js --network bsctestnet

const { ethers } = require("hardhat");

// Update PancakeSwap Router address for the target network:
// - BSC Testnet Pancake Router v2 (commonly): 0x9ac64cc6e4415144c455bd8e4837fea55603e5c3
// - BSC Mainnet Pancake Router v2: 0x10ED43C718714eb63d5aA57B78B54704E256024E
const PANCAKE_ROUTER = "0x9ac64cc6e4415144c455bd8e4837fea55603e5c3"; // testnet example
const WBNB_ADDRESS = "0xae13d989dac2f0debff460ac112a837c89baa7cd"; // testnet WBNB

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Adding liquidity as:", deployer.address);

  // ---------- CONFIG (REPLACE) ----------
  const tokenAddress = "0xPASTE_APM_TOKEN_ADDRESS";
  const liquidityTokenAmount = ethers.parseUnits("1000000", 18); // tokens to add to pool (example)
  const bnbAmount = ethers.parseUnits("1", 18); // amount of BNB to pair with tokens
  const lockerAddress = "0xPASTE_LIQUIDITY_LOCKER_ADDRESS";
  const unlockInMonths = 12; // lock duration

  // ---------- CONTRACTS ----------
  const Router = await ethers.getContractAt(
    ["function addLiquidityETH(address token, uint amountTokenDesired, uint amountTokenMin, uint amountETHMin, address to, uint deadline) payable returns (uint amountToken, uint amountETH, uint liquidity)"],
    PANCAKE_ROUTER
  );

  const Token = await ethers.getContractAt("APMToken", tokenAddress);
  const Locker = await ethers.getContractAt("LiquidityLocker", lockerAddress);

  // Approve router to spend tokens
  console.log("Approving router to spend tokens...");
  await (await Token.approve(PANCAKE_ROUTER, liquidityTokenAmount)).wait();

  // Add liquidity: token + native BNB (use addLiquidityETH)
  const deadline = Math.floor(Date.now() / 1000) + 60 * 10; // 10 minutes from now

  console.log("Calling addLiquidityETH...");
  const tx = await Router.addLiquidityETH(
    tokenAddress,
    liquidityTokenAmount,
    0, // accept any slippage (for test); adjust on mainnet
    0,
    deployer.address, // LP tokens minted to deployer
    deadline,
    { value: bnbAmount }
  );
  const receipt = await tx.wait();
  console.log("Liquidity added, tx:", receipt.transactionHash);

  // Find LP token address from receipt logs is tricky; easier: compute pair via factory or use known pair
  // Option A: If you know the pair address, use it. Option B: derive pair address using PancakeFactory
  // For simplicity we assume you have the LP token address (replace below)
  const lpTokenAddress = "0xPASTE_LP_TOKEN_ADDRESS"; // you must fill this (find via PancakeFactory or explorer)

  // Approve Locker and transfer LP tokens into Locker (owner must be deployer)
  const lpToken = await ethers.getContractAt("IERC20", lpTokenAddress);
  const lpBalance = await lpToken.balanceOf(deployer.address);
  console.log("LP tokens in deployer:", ethers.formatUnits(lpBalance, 18));

  console.log("Approving locker to pull LP tokens...");
  await (await lpToken.approve(lockerAddress, lpBalance)).wait();

  // Lock LP tokens (owner must be locker owner)
  const unlockAt = Math.floor(Date.now() / 1000) + (unlockInMonths * 30 * 24 * 60 * 60);
  const lockTx = await Locker.lock(lpTokenAddress, lpBalance, unlockAt);
  const lockReceipt = await lockTx.wait();
  console.log("LP locked in locker, tx:", lockReceipt.transactionHash);

  console.log("Done. LP locked until unix:", unlockAt);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
