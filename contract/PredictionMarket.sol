
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./APMToken.sol";
import "./MarketFactory.sol";

contract PredictionMarket {
    string public question;
    address public factory;
    APMToken public rewardToken;

    struct Prediction {
        address user;
        uint256 choice; // 1..n
    }

    Prediction[] public predictions;
    mapping(address => bool) public hasClaimed;
    uint256 public winningChoice;
    bool public isResultSet;

    uint256 public totalPredictions;
    mapping(uint256 => uint256) public choiceCount;

    event PredictionMade(address indexed user, uint256 choice);
    event ResultSet(uint256 winningChoice);
    event RewardClaimed(address indexed user, uint256 amount);

    constructor(string memory _question, address _factory) {
        question = _question;
        factory = _factory;
        rewardToken = APMToken(MarketFactory(_factory).token());
    }

    function makePrediction(uint256 _choice) external {
        require(!isResultSet, "Market closed");
        require(_choice > 0, "Choice must be > 0");

        predictions.push(Prediction(msg.sender, _choice));
        choiceCount[_choice] += 1;
        totalPredictions += 1;

        emit PredictionMade(msg.sender, _choice);
    }

    // Market owner (factory) sets result
    function setResult(uint256 _winningChoice) external {
        require(msg.sender == factory, "Only factory can set result");
        require(!isResultSet, "Result already set");
        require(_winningChoice > 0, "Winning choice must be > 0");

        winningChoice = _winningChoice;
        isResultSet = true;

        // Automatically request reward from factory
        uint256 rewardPoolBalance = MarketFactory(factory).getRewardPool();
        uint256 rewardAmount = rewardPoolBalance; // use all available pool or you can set % logic
        MarketFactory(factory).distributeReward(address(this), rewardAmount);

        emit ResultSet(_winningChoice);
    }

    function claimReward() external {
        require(isResultSet, "Result not set");
        require(!hasClaimed[msg.sender], "Already claimed");

        uint256 userChoice = 0;
        for (uint256 i = 0; i < predictions.length; i++) {
            if (predictions[i].user == msg.sender) {
                userChoice = predictions[i].choice;
                break;
            }
        }
        require(userChoice == winningChoice, "You did not win");

        uint256 rewardBalance = rewardToken.balanceOf(address(this));
        uint256 winnersCount = choiceCount[winningChoice];
        require(winnersCount > 0, "No winners");

        uint256 rewardPerWinner = rewardBalance / winnersCount;

        bool success = rewardToken.transfer(msg.sender, rewardPerWinner);
        require(success, "Reward transfer failed");

        hasClaimed[msg.sender] = true;
        emit RewardClaimed(msg.sender, rewardPerWinner);
    }

    function getPredictions() external view returns (Prediction[] memory) {
        return predictions;
    }

    function getChoiceCount(uint256 _choice) external view returns (uint256) {
        return choiceCount[_choice];
    }
}
