// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title APMToken
 * @notice Fixed-supply APM-Agro ERC20 token.
 * @dev OpenZeppelin Contracts 5.x. No public or owner mint function.
 *      The entire fixed supply is minted to initialOwner at deployment.
 */
contract APMToken is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 500_000_000 * 10**18;

    constructor(address initialOwner)
        ERC20("APM-Agro Token", "APM")
        Ownable(initialOwner)
    {
        require(initialOwner != address(0), "APM: zero initial owner");
        _mint(initialOwner, MAX_SUPPLY);
    }
}
