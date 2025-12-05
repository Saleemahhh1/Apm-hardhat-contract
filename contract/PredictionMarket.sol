// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20Ext {
    function balanceOf(address) external view returns (uint256);
}

contract PredictionMarket is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;        // APM token address
    address public factory;               // MarketFactory address / market owner
    string public question;
    uint256 public deadline;              // betting cutoff (timestamp)
    bool public resolved;
    uint8 public winningChoice;           // 0 unset, 1..n set
    uint256 public feeBps;                // fee taken from winners (sent to treasury)
    address public treasury;

    // choice => total staked
    mapping(uint256 => uint256) public totalStakedPerChoice;
    // user => choice => amount staked
    mapping(address => mapping(uint256 => uint256)) public stakes;
    // user claimed mapping
    mapping(address => bool) public hasClaimed;

    event BetPlaced(address indexed user, uint256 indexed choice, uint256 amount);
    event MarketResolved(uint8 winningChoice);
    event RewardClaimed(address indexed user, uint256 amount);

    modifier onlyFactory() {
        require(msg.sender == factory, "Only factory");
        _;
    }

    modifier beforeDeadline() {
        require(block.timestamp < deadline, "Betting closed");
        _;
    }

    constructor(
        address _token,
        string memory _question,
        uint256 _deadline,
        address _factory,
        uint256 _feeBps,
        address _treasury
    ) {
        require(_token != address(0), "token zero");
        require(_factory != address(0), "factory zero");
        require(_treasury != address(0), "treasury zero");
        token = IERC20(_token);
        question = _question;
        deadline = _deadline;
        factory = _factory;
        feeBps = _feeBps;
        treasury = _treasury;
    }

    /// @notice place a bet on a choice; requires prior approve
    function placeBet(uint256 choice, uint256 amount) external nonReentrant beforeDeadline {
        require(choice > 0, "invalid choice");
        require(amount > 0, "zero amount");

        // transfer tokens to market
        token.safeTransferFrom(msg.sender, address(this), amount);

        stakes[msg.sender][choice] += amount;
        totalStakedPerChoice[choice] += amount;

        emit BetPlaced(msg.sender, choice, amount);
    }

    /// @notice set result; only callable by factory (or factory owner logic)
    function setResult(uint8 _winningChoice) external onlyFactory {
        require(!resolved, "already resolved");
        require(_winningChoice > 0, "invalid");
        resolved = true;
        winningChoice = _winningChoice;

        // optional: the factory can distribute reward pool to this market before resolving,
        // but factory can also fund this contract any time via token.transfer
        emit MarketResolved(_winningChoice);
    }

    /// @notice claim reward if user staked on winning choice
    function claim() external nonReentrant {
        require(resolved, "not resolved");
        require(!hasClaimed[msg.sender], "claimed");

        uint256 userStake = stakes[msg.sender][winningChoice];
        require(userStake > 0, "no winning stake");

        uint256 winnersPool = totalStakedPerChoice[winningChoice];

        // compute total pool of losers
        uint256 totalAll = 0;
        // WARNING: to compute totalAll we must know set of choices used by market.
        // Simple approach: sum over reasonable max choices or factory sets choices set.
        // For safety we compute sum of all staked in contract:
        uint256 contractBalance = token.balanceOf(address(this));
        // winners get their original stake + proportional share of losers from contractBalance
        // gross = userStake + (userStake / winnersPool) * (contractBalance - winnersPool)
        uint256 losersPool = contractBalance - winnersPool;
        uint256 shareOfLoser = (userStake * losersPool) / winnersPool;
        uint256 gross = userStake + shareOfLoser;

        uint256 fee = (gross * feeBps) / 10000;
        uint256 payout = gross - fee;

        // mark claimed & zero out user's stake for that choice
        hasClaimed[msg.sender] = true;
        stakes[msg.sender][winningChoice] = 0;

        // transfer fee to treasury and payout to user
        if (fee > 0) {
            token.safeTransfer(treasury, fee);
        }
        token.safeTransfer(msg.sender, payout);

        emit RewardClaimed(msg.sender, payout);
    }

    // allow factory to fund market reward pool
    function fund(uint256 amount) external {
        token.safeTransferFrom(msg.sender, address(this), amount);
    }
}
