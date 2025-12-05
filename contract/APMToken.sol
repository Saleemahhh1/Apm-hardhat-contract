// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract APMToken is ERC20, Ownable {
    uint8 private constant DECIMALS = 18;
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** uint256(DECIMALS); // 1B

    event TokensMinted(address indexed to, uint256 amount);

    constructor() ERC20("Agro Prediction Market", "APM") {
        _mint(msg.sender, INITIAL_SUPPLY);
        emit TokensMinted(msg.sender, INITIAL_SUPPLY);
    }

    // rescue tokens mistakenly sent
    function rescueERC20(address tokenAddress, address to) external onlyOwner {
        require(to != address(0), "zero");
        IERC20(tokenAddress).transfer(to, IERC20(tokenAddress).balanceOf(address(this)));
    }
}
