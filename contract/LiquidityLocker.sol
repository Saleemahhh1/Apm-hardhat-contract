// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title LiquidityLocker
 * @notice Time-locks ERC20 liquidity-provider (LP) tokens.
 * @dev OpenZeppelin Contracts 5.x. Owner deposits LP tokens into a numbered lock.
 *      Only the owner can create locks and withdraw them after their unlock time.
 */
contract LiquidityLocker is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct LockInfo {
        address lpToken;
        uint256 amount;
        uint256 unlockAt;
        bool withdrawn;
    }

    LockInfo[] private locks;

    event Locked(
        uint256 indexed lockId,
        address indexed lpToken,
        uint256 amount,
        uint256 unlockAt,
        address indexed locker
    );
    event Withdrawn(
        uint256 indexed lockId,
        address indexed lpToken,
        uint256 amount,
        address indexed to
    );

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Pull LP tokens from the owner and create a time lock.
     *         The owner must approve this contract first.
     */
    function lock(address lpToken, uint256 amount, uint256 unlockAt)
        external
        onlyOwner
        nonReentrant
        returns (uint256 lockId)
    {
        require(lpToken != address(0), "Locker: zero LP token");
        require(lpToken.code.length > 0, "Locker: token not contract");
        require(amount > 0, "Locker: zero amount");
        require(unlockAt > block.timestamp, "Locker: unlock not future");

        IERC20 token = IERC20(lpToken);
        uint256 balanceBefore = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = token.balanceOf(address(this)) - balanceBefore;
        require(received == amount, "Locker: incorrect amount received");

        locks.push(
            LockInfo({
                lpToken: lpToken,
                amount: amount,
                unlockAt: unlockAt,
                withdrawn: false
            })
        );

        lockId = locks.length - 1;
        emit Locked(lockId, lpToken, amount, unlockAt, msg.sender);
    }

    function withdraw(uint256 lockId, address to) external onlyOwner nonReentrant {
        require(to != address(0), "Locker: zero receiver");
        require(lockId < locks.length, "Locker: invalid lock ID");

        LockInfo storage info = locks[lockId];
        require(!info.withdrawn, "Locker: already withdrawn");
        require(block.timestamp >= info.unlockAt, "Locker: still locked");

        // Mark withdrawn before the external token transfer.
        info.withdrawn = true;
        IERC20(info.lpToken).safeTransfer(to, info.amount);

        emit Withdrawn(lockId, info.lpToken, info.amount, to);
    }

    function locksCount() external view returns (uint256) {
        return locks.length;
    }

    function getLock(uint256 lockId) external view returns (LockInfo memory) {
        require(lockId < locks.length, "Locker: invalid lock ID");
        return locks[lockId];
    }
}
