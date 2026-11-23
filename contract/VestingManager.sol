// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title VestingManager
 * @notice Holds and releases a capped 5% of the 500M APM supply for team vesting.
 * @dev OpenZeppelin Contracts 5.x. The 5% cap is 25,000,000 APM.
 *      Owner must approve this contract before createVesting().
 *      Vesting duration is measured from startTime; cliff is measured from startTime.
 */
contract VestingManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant TEAM_VESTING_CAP = 25_000_000 * 10**18;

    struct VestingInfo {
        uint256 totalAmount;
        uint256 amountReleased;
        uint256 startTime;
        uint256 cliffTime;
        uint256 endTime;
    }

    IERC20 public immutable token;

    mapping(address => VestingInfo) public vestings;

    // Cumulative amount ever allocated; cannot exceed the 5% team vesting cap.
    uint256 public totalVestingAllocated;

    // Current unpaid vesting liability across all beneficiaries.
    uint256 public totalOutstanding;

    event VestingCreated(
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffTime,
        uint256 endTime
    );
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event UnallocatedTokensWithdrawn(address indexed to, uint256 amount);

    constructor(IERC20 tokenAddress) Ownable(msg.sender) {
        require(address(tokenAddress) != address(0), "Vesting: zero token");
        require(address(tokenAddress).code.length > 0, "Vesting: token not contract");
        token = tokenAddress;
    }

    /**
     * @notice Create a vesting schedule and pull its full allocation into escrow.
     * @param beneficiary Wallet that will receive vested tokens.
     * @param totalAmount Amount in token base units (18 decimals for APM).
     * @param startTime Unix timestamp when vesting starts.
     * @param cliffDuration Seconds before the first release is permitted.
     * @param vestingDuration Total duration from startTime to full vesting.
     *
     * Example recommended schedule: 12-month cliff and 36-month total duration.
     * The 36 months includes the 12-month cliff; it is not 36 months after cliff.
     */
    function createVesting(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    ) external onlyOwner nonReentrant {
        require(beneficiary != address(0), "Vesting: zero beneficiary");
        require(totalAmount > 0, "Vesting: zero amount");
        require(vestings[beneficiary].totalAmount == 0, "Vesting: beneficiary exists");
        require(startTime >= block.timestamp, "Vesting: start in past");
        require(vestingDuration > 0, "Vesting: zero duration");
        require(cliffDuration <= vestingDuration, "Vesting: cliff exceeds duration");
        require(
            totalVestingAllocated + totalAmount <= TEAM_VESTING_CAP,
            "Vesting: exceeds 5% team cap"
        );

        uint256 cliffTime = startTime + cliffDuration;
        uint256 endTime = startTime + vestingDuration;
        require(endTime > startTime, "Vesting: invalid end");

        // Effects before token interaction; nonReentrant is an additional safeguard.
        vestings[beneficiary] = VestingInfo({
            totalAmount: totalAmount,
            amountReleased: 0,
            startTime: startTime,
            cliffTime: cliffTime,
            endTime: endTime
        });
        totalVestingAllocated += totalAmount;
        totalOutstanding += totalAmount;

        uint256 balanceBefore = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), totalAmount);
        uint256 received = token.balanceOf(address(this)) - balanceBefore;
        require(received == totalAmount, "Vesting: incorrect amount received");

        emit VestingCreated(
            beneficiary,
            totalAmount,
            startTime,
            cliffTime,
            endTime
        );
    }

    function releaseTokens() external nonReentrant {
        VestingInfo storage vest = vestings[msg.sender];
        require(vest.totalAmount > 0, "Vesting: no schedule");

        uint256 releasable = calculatableVest(msg.sender);
        require(releasable > 0, "Vesting: nothing releasable");

        vest.amountReleased += releasable;
        totalOutstanding -= releasable;

        token.safeTransfer(msg.sender, releasable);
        emit TokensReleased(msg.sender, releasable);
    }

    function calculatableVest(address beneficiary) public view returns (uint256) {
        VestingInfo memory vest = vestings[beneficiary];

        if (vest.totalAmount == 0 || block.timestamp < vest.cliffTime) {
            return 0;
        }

        uint256 vestedAmount;
        if (block.timestamp >= vest.endTime) {
            vestedAmount = vest.totalAmount;
        } else {
            vestedAmount =
                (vest.totalAmount * (block.timestamp - vest.startTime))
                / (vest.endTime - vest.startTime);
        }

        if (vestedAmount <= vest.amountReleased) {
            return 0;
        }
        return vestedAmount - vest.amountReleased;
    }

    /**
     * @notice Withdraw only tokens that are not reserved for unpaid vesting.
     *         This cannot withdraw beneficiaries' outstanding allocations.
     */
    function withdrawUnallocated(address to, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        require(to != address(0), "Vesting: zero receiver");
        uint256 balance = token.balanceOf(address(this));
        require(balance >= totalOutstanding, "Vesting: underfunded");
        uint256 available = balance - totalOutstanding;
        require(amount <= available, "Vesting: amount reserved");

        token.safeTransfer(to, amount);
        emit UnallocatedTokensWithdrawn(to, amount);
    }
}
