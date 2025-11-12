
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PredictionMarket.sol";
import "./APMToken.sol";

contract MarketFactory {
    address[] public allMarkets;
    mapping(address => address) public userMarkets;
    APMToken public token;

    event MarketCreated(address indexed marketAddress, string question);

    constructor(0x97b619d007ac9fC06109b5162da22603ee316470) {
        token = APMToken(0x97b619d007ac9fC06109b5162da22603ee316470);
    }

    function createMarket(string memory _question) external {
        PredictionMarket market = new PredictionMarket(_question);
        allMarkets.push(address(market));
        userMarkets[msg.sender] = address(market);
        emit MarketCreated(address(market), _question);
    }

    function getAllMarkets() external view returns (address[] memory) {
        return allMarkets;
    }
}
