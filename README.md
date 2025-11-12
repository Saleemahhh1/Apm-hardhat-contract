# APM Prediction Market

## Project Overview
This project is a decentralized **Prediction Market** powered by **APM Token**. Users can create prediction markets, place bets using APM tokens, and earn rewards based on outcomes.

### Problem Solved
Traditional prediction markets are centralized and lack transparency. This project provides a **trustless, verifiable, and transparent** way for users to participate in prediction markets using blockchain.

---

## Smart Contracts

### 1. APMToken.sol
- ERC20 token used for betting and rewards.
- **Deployment Address:** `0x97b619d007ac9fC06109b5162da22603ee316470`
- **Verified Source:** [Sourcify Verification Link](https://repo.sourcify.dev/97/0x97b619d007ac9fC06109b5162da22603ee316470)

### 2. PredictionMarket.sol
- Handles creation of markets, placing bets, and distributing rewards.
- **Deployment Address:** `0xdD2A365eaB1692f27C481a78ae7c85b9c303e5D1`
- **Verified Source:** [Sourcify Verification Link](https://repo.sourcify.dev/97/0xdD2A365eaB1692f27C481a78ae7c85b9c303e5D1)

### 3. MarketFactory.sol
- Factory contract to create new prediction markets.
- Tracks user-created markets.
- **Deployment Address:** `0xd6a3cfd9653d88fd2a4efe7366bd0a19f74a70e9`
- **Verified Source:** [Sourcify/Remix Link](https://remix.ethereum.org/#)

---

## Deployment Details

| Contract | Address | Verified Source |
|----------|---------|----------------|
| APMToken | `0x97b619d007ac9fC06109b5162da22603ee316470` | [Sourcify](https://repo.sourcify.dev/97/0x97b619d007ac9fC06109b5162da22603ee316470) |
| PredictionMarket | `0xdD2A365eaB1692f27C481a78ae7c85b9c303e5D1` | [Sourcify](https://repo.sourcify.dev/97/0xdD2A365eaB1692f27C481a78ae7c85b9c303e5D1) |
| MarketFactory | `0xd6a3cfd9653d88fd2a4efe7366bd0a19f74a70e9` | Verified on Remix/Sourcify |

---

## How to Interact (Demo)

### 1. Setup
1. Connect your wallet (MetaMask) to the correct Ethereum network.
2. Open **Remix** and load contracts.

### 2. Mint APM Tokens
- Example: Mint `1000 APM` to your wallet.
- Screenshot placeholder: `![Mint Tokens](./screenshots/mint_tokens.png)`

### 3. Create a Market via MarketFactory
- Input example:
  - Market name: `"Will Ethereum price exceed $5000 by Dec 2025?"`
  - Initial token stake: `100 APM`
- Screenshot placeholder: `![Create Market](./screenshots/create_market.png)`

### 4. Place Bets in PredictionMarket
- Example:
  - Bet `50 APM` on `"Yes"` outcome.
- Transaction hash example: `0x1d3...2fc9b`
- Screenshot placeholder: `![Place Bet](./screenshots/place_bet.png)`

### 5. Resolve Outcome
- Example:
  - Market outcome: `"Yes"`
  - Reward distribution automatically done in **APM tokens**
- Screenshot placeholder: `![Reward Distribution](./screenshots/reward.png)`

---

## Sample Transactions (Mainnet / Testnet)

| Action | Tx Hash | Notes |
|--------|---------|-------|
| Deploy APMToken | `0x753...b8d8d` | Verified on Sourcify |
| Deploy PredictionMarket | `0x1d3...2fc9b` | Verified on Sourcify |
| Deploy MarketFactory | `0xd636c00f4632b0b31bd85263881a1bab2d767ff095527ac80ce2637f9d74a4d9` | Tracks user-created markets |

---

## Project Structure
