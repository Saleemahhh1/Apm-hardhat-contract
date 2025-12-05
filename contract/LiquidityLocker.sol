// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
LiquidityLocker.sol
- Simple locker to hold LP tokens until unlock timestamp
- Owner = locker deployer; recommend transferOwnership to multisig (Gnosis)
- Anyone can deposit LP tokens (the locker accepts ERC20s)
- Owner can set unlock timestamp when locking
- After unlock time, owner can withdraw LP tokens to a receiver
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LiquidityLocker is Ownable {
    event Locked(address indexed lpToken, uint256 amount, uint256 unlockAt, address indexed locker);
    event Withdrawn(address indexed lpToken, uint256 amount, address indexed to);

    struct LockInfo {
        address lpToken;
        uint256 amount;
        uint256 unlockAt; // unix timestamp
        bool withdrawn;
    }

    LockInfo[] public locks;

    // Lock LP tokens (transfer LP tokens to this contract first via approve+transferFrom)
    function lock(address lpToken, uint256 amount, uint256 unlockAt) external onlyOwner returns (uint256) {
        require(lpToken != address(0), "lp zero");
        require(amount > 0, "amount zero");
        require(unlockAt > block.timestamp, "unlock must be future");

        // pull tokens from owner
        IERC20(lpToken).transferFrom(msg.sender, address(this), amount);

        locks.push(LockInfo({
            lpToken: lpToken,
            amount: amount,
            unlockAt: unlockAt,
            withdrawn: false
        }));

        uint256 id = locks.length - 1;
        emit Locked(lpToken, amount, unlockAt, msg.sender);
        return id;
    }

    // Owner withdraws after unlock
    function withdraw(uint256 id, address to) external onlyOwner {
        require(id < locks.length, "invalid id");
        LockInfo storage info = locks[id];
        require(!info.withdrawn, "already withdrawn");
        require(block.timestamp >= info.unlockAt, "still locked");
        info.withdrawn = true;
        IERC20(info.lpToken).transfer(to, info.amount);
        emit Withdrawn(info.lpToken, info.amount, to);
    }

    // View helper
    function locksCount() external view returns (uint256) {
        return locks.length;
    }

    // Get lock by id
    function getLock(uint256 id) external view returns (LockInfo memory) {
        return locks[id];
    }
}
