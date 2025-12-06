// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VestingManager is Ownable {
    struct VestingInfo {
        uint256 totalAmount;    
        uint256 amountReleased; 
        uint256 startTime;      
        uint256 cliffTime;      
        uint256 endTime;        
    }

    IERC20 public token;

    mapping(address => VestingInfo) public vestings;

    event VestingCreated(
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffTime,
        uint256 endTime
    );

    event TokensReleased(address indexed beneficiary, uint256 amount);

    constructor(IERC20 _token) Ownable(msg.sender) {
        token = _token;
    }

    function createVesting(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    ) external onlyOwner {

        require(beneficiary != address(0), "Invalid address!");
        require(totalAmount > 0, "Amount must be > 0");
        require(vestings[beneficiary].totalAmount == 0, "Already has vesting!");

        uint256 cliffTime = startTime + cliffDuration;
        uint256 endTime   = startTime + vestingDuration;

        vestings[beneficiary] = VestingInfo({
            totalAmount: totalAmount,
            amountReleased: 0,
            startTime: startTime,
            cliffTime: cliffTime,
            endTime: endTime
        });

        emit VestingCreated(
            beneficiary,
            totalAmount,
            startTime,
            cliffTime,
            endTime
        );
    }

    function releaseTokens() external {
        VestingInfo storage vest = vestings[msg.sender];
        require(vest.totalAmount > 0, "No vesting!");

        require(block.timestamp >= vest.cliffTime, "Cliff not reached!");

        uint256 vestedAmount = calculatableVest(msg.sender);
        require(vestedAmount > 0, "No releasable tokens");

        vest.amountReleased += vestedAmount;

        require(token.transfer(msg.sender, vestedAmount), "Transfer failed!");

        emit TokensReleased(msg.sender, vestedAmount);
    }

    function calculatableVest(address beneficiary) public view returns (uint256) {
        VestingInfo memory vest = vestings[beneficiary];

        if (block.timestamp < vest.cliffTime) {
            return 0;
        }

        if (block.timestamp >= vest.endTime) {
            return vest.totalAmount - vest.amountReleased;
        }

        uint256 vested = (vest.totalAmount * (block.timestamp - vest.startTime)) 
                         / (vest.endTime - vest.startTime);

        return vested - vest.amountReleased;
    }

    function withdrawUnallocated(address to, uint256 amount) external onlyOwner {
        require(token.transfer(to, amount), "Withdraw failed");
    }
}
