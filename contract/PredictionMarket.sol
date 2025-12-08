
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20Ext {
    function balanceOf(address) external view returns (uint256);
}

contract PredictionMarket is Ownable {   // ReentrancyGuard an cire
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    address public factory;
    string public question;
    uint256 public deadline;
    bool public resolved;
    uint8 public winningChoice;
    uint256 public feeBps;
    address public treasury;

    mapping(uint256 => uint256) public totalStakedPerChoice;
    mapping(address => mapping(uint256 => uint256)) public stakes;
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
        address _treasury,
        address _owner
    ) Ownable(_owner) // ✅ wuce owner a nan
    {
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

    function placeBet(uint256 choice, uint256 amount) external beforeDeadline {
        require(choice > 0, "invalid choice");
        require(amount > 0, "zero amount");

        token.safeTransferFrom(msg.sender, address(this), amount);

        stakes[msg.sender][choice] += amount;
        totalStakedPerChoice[choice] += amount;

        emit BetPlaced(msg.sender, choice, amount);
    }

    function setResult(uint8 _winningChoice) external onlyFactory {
        require(!resolved, "already resolved");
        require(_winningChoice > 0, "invalid");

        resolved = true;
        winningChoice = _winningChoice;

        emit MarketResolved(_winningChoice);
    }

    function claim() external {
        require(resolved, "not resolved");
        require(!hasClaimed[msg.sender], "claimed");

        uint256 userStake = stakes[msg.sender][winningChoice];
        require(userStake > 0, "no winning stake");

        uint256 winnersPool = totalStakedPerChoice[winningChoice];
        uint256 contractBalance = token.balanceOf(address(this));
        uint256 losersPool = contractBalance - winnersPool;
        uint256 shareOfLoser = (userStake * losersPool) / winnersPool;
        uint256 gross = userStake + shareOfLoser;

        uint256 fee = (gross * feeBps) / 10000;
        uint256 payout = gross - fee;

        hasClaimed[msg.sender] = true;
        stakes[msg.sender][winningChoice] = 0;

        if (fee > 0) token.safeTransfer(treasury, fee);
        token.safeTransfer(msg.sender, payout);

        emit RewardClaimed(msg.sender, payout);
    }

    function fund(uint256 amount) external {
        token.safeTransferFrom(msg.sender, address(this), amount);
    }
}
