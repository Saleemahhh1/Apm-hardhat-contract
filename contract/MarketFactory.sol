
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PredictionMarket.sol";
import "./APMToken.sol";

contract MarketFactory {
    address[] public allMarkets;
    mapping(address => address) public userMarkets;
    APMToken public token;

    event MarketCreated(address indexed marketAddress, string question);

    constructor(address tokenAddress) {
        token = APMToken(tokenAddress);
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
