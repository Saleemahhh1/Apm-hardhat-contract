
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PredictionMarket.sol";
import "./APMToken.sol";

contract MarketFactory {
    address[] public allMarkets;
    mapping(address => address[]) public userMarkets;
    APMToken public token;
    uint256 public constant CREATION_FEE = 100 * 10**18; // 100 APMTokens
    uint256 public rewardPool;
    address public owner;

    event MarketCreated(address indexed marketAddress, string question, address indexed creator);
    event RewardDistributed(address indexed market, uint256 amount);

    constructor() {
        token = APMToken(0x97b619d007ac9fC06109b5162da22603ee316470);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    // Create market and add to reward pool automatically
    function createMarket(string memory _question) external {
        require(token.balanceOf(msg.sender) >= CREATION_FEE, "Insufficient APM tokens");
        bool success = token.transferFrom(msg.sender, address(this), CREATION_FEE);
        require(success, "Token transfer failed");

        uint256 poolShare = (CREATION_FEE * 80) / 100;
        rewardPool += poolShare;

        PredictionMarket market = new PredictionMarket(_question, address(this));
        allMarkets.push(address(market));
        userMarkets[msg.sender].push(address(market));

        emit MarketCreated(address(market), _question, msg.sender);
    }

    // Called by PredictionMarket when market is closed
    function distributeReward(address _market, uint256 _amount) external {
        require(msg.sender == _market, "Only market can request reward");
        require(_amount <= rewardPool, "Not enough in reward pool");

        rewardPool -= _amount;
        bool success = token.transfer(_market, _amount);
        require(success, "Token transfer failed");

        emit RewardDistributed(_market, _amount);
    }

    function getAllMarkets() external view returns (address[] memory) {
        return allMarkets;
    }

    function getUserMarkets(address _user) external view returns (address[] memory) {
        return userMarkets[_user];
    }

    function getRewardPool() external view returns (uint256) {
        return rewardPool;
    }
}
