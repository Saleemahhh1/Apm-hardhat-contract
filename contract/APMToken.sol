// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract APMToken is ERC20, Ownable {

    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18;

    constructor(0x7375a9348294244559cedea84b69bd2d3855d220)
        ERC20("APM-Agro Token", "APM")
        Ownable(initialOwner)
    {
        _mint(initialOwner, MAX_SUPPLY);
    }
}
