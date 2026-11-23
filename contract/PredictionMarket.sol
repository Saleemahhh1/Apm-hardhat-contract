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
‎    //                    RESOLUTION SNAPSHOTS
‎    // =============================================================
‎
‎    uint256 public yesPoolAtResolution;
‎    uint256 public noPoolAtResolution;
‎
‎    uint256 public winnersPoolAtResolution;
‎    uint256 public losersPoolAtResolution;
‎
‎    uint256 public totalPoolAtResolution;
‎
‎    // Claim accounting
‎    uint256 public totalWinningStakeClaimed;
‎
‎    uint256 public totalPaidOut;
‎
‎    uint256 public totalFeesCollected;
‎
‎    uint256 public totalRefunded;
‎
‎    // =============================================================
‎    //                            EVENTS
‎    // =============================================================
‎
‎    event BetPlaced(
‎        address indexed user,
‎        uint256 indexed choice,
‎        uint256 amount
‎    );
‎
‎    event MarketResolved(
‎        uint8 indexed winningChoice,
‎        uint256 yesPool,
‎        uint256 noPool,
‎        bool refundMode
‎    );
‎
‎    event RewardClaimed(
‎        address indexed user,
‎        uint256 winningStake,
‎        uint256 profitShare,
‎        uint256 fee,
‎        uint256 payout
‎    );
‎
‎    event RefundClaimed(
‎        address indexed user,
‎        uint256 amount
‎    );
‎
‎    event RoundingDustTransferred(
‎        address indexed treasury,
‎        uint256 amount
‎    );
‎
‎    // =============================================================
‎    //                            MODIFIERS
‎    // =============================================================
‎
‎    modifier onlyFactory() {
‎        require(
‎            msg.sender == factory,
‎            "Only factory"
‎        );
‎        _;
‎    }
‎
‎    modifier beforeDeadline() {
‎        require(
‎            block.timestamp < deadline,
‎            "Betting closed"
‎        );
‎        _;
‎    }
‎
‎    // =============================================================
