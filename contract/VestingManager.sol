// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/*
VestingManager.sol
- Manage multiple vesting schedules (beneficiary, total, start, cliffDuration, duration)
- Owner (multisig) creates schedules and funds contract with APM tokens.
- Beneficiaries pull vested tokens via release(scheduleId).
- SafeERC20 used by deploy script when funding.
*/

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract VestingManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Vesting {
        address beneficiary;
        uint256 totalAmount;  // total allocated to this vesting schedule
        uint256 released;     // amount already released
        uint256 start;        // start timestamp (TGE or epoch)
        uint256 cliff;        // cliff seconds from start
        uint256 duration;     // total duration seconds from start (after which full amount vested)
        bool revocable;
        bool revoked;
    }

    IERC20 public immutable token;
    Vesting[] public vestings;

    event VestingCreated(uint256 indexed id, address indexed beneficiary, uint256 totalAmount, uint256 start, uint256 cliff, uint256 duration, bool revocable);
    event Released(uint256 indexed id, address indexed beneficiary, uint256 amount);
    event Revoked(uint256 indexed id, address indexed beneficiary);

    constructor(IERC20 _token) {
        require(address(_token) != address(0), "token zero");
        token = _token;
    }

    /**
     * @dev create vesting schedule
     * @param beneficiary recipient address
     * @param totalAmount total tokens allocated to schedule (in token decimals)
     * @param start unix timestamp when vesting starts (TGE recommended)
     * @param cliffDuration seconds after start before any tokens vest
     * @param duration seconds from start to full vest (must be >= cliffDuration)
     * @param revocable whether owner can revoke unvested tokens
     */
    function createVesting(
        address beneficiary,
        uint256 totalAmount,
        uint256 start,
        uint256 cliffDuration,
        uint256 duration,
        bool revocable
    ) external onlyOwner returns (uint256) {
        require(beneficiary != address(0), "beneficiary zero");
        require(totalAmount > 0, "amount zero");
        require(duration > 0, "duration zero");
        require(cliffDuration <= duration, "cliff > duration");

        Vesting memory v = Vesting({
            beneficiary: beneficiary,
            totalAmount: totalAmount,
            released: 0,
            start: start,
            cliff: cliffDuration,
            duration: duration,
            revocable: revocable,
            revoked: false
        });

        vestings.push(v);
        uint256 id = vestings.length - 1;
        emit VestingCreated(id, beneficiary, totalAmount, start, cliffDuration, duration, revocable);
        return id;
    }

    function vestingCount() external view returns (uint256) {
        return vestings.length;
    }

    /// @notice compute vested amount at current block.timestamp
    function vestedAmount(uint256 id) public view returns (uint256) {
        require(id < vestings.length, "invalid id");
        Vesting storage v = vestings[id];

        if (v.revoked) {
            // if revoked, vested amount is whatever was vested before revocation (released tracked)
            return v.released;
        }

        if (block.timestamp < v.start + v.cliff) {
            return 0;
        }
        if (block.timestamp >= v.start + v.duration) {
            return v.totalAmount;
        }
        uint256 timeFromStart = block.timestamp - v.start;
        uint256 vested = (v.totalAmount * timeFromStart) / v.duration;
        return vested;
    }

    function releasableAmount(uint256 id) public view returns (uint256) {
        require(id < vestings.length, "invalid id");
        Vesting storage v = vestings[id];
        uint256 vested = vestedAmount(id);
        if (vested <= v.released) return 0;
        return vested - v.released;
    }

    /// @notice release vested tokens to beneficiary (owner or beneficiary can call)
    function release(uint256 id, address to) public nonReentrant {
        require(id < vestings.length, "invalid id");
        Vesting storage v = vestings[id];
        require(!v.revoked, "revoked");

        uint256 amount = releasableAmount(id);
        require(amount > 0, "no releasable");

        v.released += amount;
        token.safeTransfer(to, amount);
        emit Released(id, to, amount);
    }

    /// @notice convenience: beneficiary releases their own vested tokens
    function releaseFor(uint256 id) external {
        Vesting storage v = vestings[id];
        require(msg.sender == v.beneficiary, "not beneficiary");
        release(id, msg.sender);
    }

    /// @notice owner can revoke (if revocable), returning unvested tokens to owner
    function revoke(uint256 id) external onlyOwner nonReentrant {
        require(id < vestings.length, "invalid id");
        Vesting storage v = vestings[id];
        require(v.revocable, "not revocable");
        require(!v.revoked, "already revoked");

        uint256 vested = vestedAmount(id);
        uint256 unreleasedVested = 0;
        if (vested > v.released) unreleasedVested = vested - v.released;
        uint256 refund = 0;
        if (v.totalAmount > vested) refund = v.totalAmount - vested;

        v.revoked = true;

        // pay any vested but unreleased to beneficiary
        if (unreleasedVested > 0) {
            v.released += unreleasedVested;
            token.safeTransfer(v.beneficiary, unreleasedVested);
            emit Released(id, v.beneficiary, unreleasedVested);
        }

        // return refund (unvested) to owner (multisig)
        if (refund > 0) {
            token.safeTransfer(owner(), refund);
        }

        emit Revoked(id, v.beneficiary);
    }

    /// @notice withdraw tokens that are not allocated to any vesting schedule (owner only)
    function withdrawUnallocated(address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "zero");
        uint256 balance = token.balanceOf(address(this));
        uint256 allocated = 0;
        for (uint256 i = 0; i < vestings.length; i++) {
            allocated += (vestings[i].totalAmount - vestings[i].released);
        }
        require(balance >= allocated + amount, "insufficient unallocated");
        token.safeTransfer(to, amount);
    }
}
