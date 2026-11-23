‎// SPDX-License-Identifier: MIT
‎pragma solidity ^0.8.20;
‎
‎import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
‎import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
‎import "@openzeppelin/contracts/access/Ownable.sol";
‎import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
‎
‎contract PredictionMarket is Ownable, ReentrancyGuard {
‎    using SafeERC20 for IERC20;
‎
‎    // =============================================================
‎    //                         CONFIGURATION
‎    // =============================================================
‎
‎    IERC20 public immutable token;
‎
‎    address public immutable factory;
‎    address public immutable treasury;
‎
‎    string public question;
‎
‎    uint256 public immutable deadline;
‎
‎    uint256 public immutable feeBps;
‎
‎    // Maximum protocol fee = 10%
‎    uint256 public constant MAX_FEE_BPS = 1000;
‎
‎    uint256 public constant BPS_DENOMINATOR = 10000;
‎
‎    // Binary prediction:
‎    // 1 = YES
‎    // 2 = NO
‎
‎    uint256 public constant YES = 1;
‎    uint256 public constant NO = 2;
‎
‎    // =============================================================
‎    //                         MARKET STATE
‎    // =============================================================
‎
‎    bool public resolved;
‎    bool public refundMode;
‎
‎    uint8 public winningChoice;
‎
‎    // Total stakes for each outcome
‎    mapping(uint256 => uint256) public totalStakedPerChoice;
‎
‎    // User stakes
‎    mapping(address => mapping(uint256 => uint256))
‎        public stakes;
‎
‎    // Prevent double claiming
‎    mapping(address => bool) public hasClaimed;
‎
‎    // =============================================================
