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

//                    RESOLUTION SNAPSHOTS
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

 //                          CONSTRUCTOR
‎    // =============================================================
‎
‎    constructor(
‎        address _token,
‎        string memory _question,
‎        uint256 _deadline,
‎        address _factory,
‎        uint256 _feeBps,
‎        address _treasury,
‎        address _owner
‎    )
‎        Ownable(_owner)
‎    {
‎        require(
‎            _token != address(0),
‎            "Token zero"
‎        );
‎
‎        require(
‎            _token.code.length > 0,
‎            "Invalid token contract"
‎        );
‎
‎        require(
‎            _factory != address(0),
‎            "Factory zero"
‎        );
‎
‎        require(
‎            _factory.code.length > 0,
‎            "Invalid factory"
‎        );
‎
‎        require(
‎            _treasury != address(0),
‎            "Treasury zero"
‎        );
‎
‎        require(
‎            bytes(_question).length > 0,
‎            "Question required"
‎        );
‎
‎        require(
‎            _deadline > block.timestamp,
‎            "Invalid deadline"
‎        );
‎
‎        require(
‎            _feeBps <= MAX_FEE_BPS,
‎            "Fee exceeds maximum"
‎        );
‎
‎        token = IERC20(_token);
‎
‎        factory = _factory;
‎
‎        treasury = _treasury;
‎
‎        question = _question;
‎
‎        deadline = _deadline;
‎
‎        feeBps = _feeBps;
‎    }
‎
‎    // =============================================================
‎    //                         PLACE BET
‎    // =============================================================
‎
‎    function placeBet(
‎        uint256 choice,
‎        uint256 amount
‎    )
‎        external
‎        beforeDeadline
‎        nonReentrant
‎    {
‎        require(
‎            !resolved,
‎            "Market resolved"
‎        );
‎
‎        require(
‎            choice == YES || choice == NO,
‎            "Invalid choice"
‎        );
‎
‎        require(
‎            amount > 0,
‎            "Amount zero"
‎        );
‎
‎        // Check balance before transfer.
‎        uint256 balanceBefore = token.balanceOf(
‎            address(this)
‎        );
‎
‎        // Transfer tokens from user.
‎        token.safeTransferFrom(
‎            msg.sender,
‎            address(this),
‎            amount
‎        );
‎
‎        // Check actual amount received.
‎        uint256 balanceAfter = token.balanceOf(
‎            address(this)
‎        );
‎
‎        require(
‎            balanceAfter - balanceBefore == amount,
‎            "Unsupported token transfer"
‎        );
‎
‎        // Update user stake.
‎        stakes[msg.sender][choice] += amount;
‎
‎        // Update outcome pool.
‎        totalStakedPerChoice[choice] += amount;
‎
‎        emit BetPlaced(
‎            msg.sender,
‎            choice,
‎            amount
‎        );
‎    }
‎
‎    // =============================================================

 //                         RESOLVE MARKET
‎    // =============================================================
‎
‎    function setResult(
‎        uint8 _winningChoice
‎    )
‎        external
‎        onlyFactory
‎    {
‎        require(
‎            !resolved,
‎            "Already resolved"
‎        );
‎
‎        require(
‎            block.timestamp >= deadline,
‎            "Deadline not reached"
‎        );
‎
‎        require(
‎            _winningChoice == YES ||
‎            _winningChoice == NO,
‎            "Invalid winning choice"
‎        );
‎
‎        resolved = true;
‎
‎        winningChoice = _winningChoice;
‎
‎        // Snapshot both pools.
‎        yesPoolAtResolution =
‎            totalStakedPerChoice[YES];
‎
‎        noPoolAtResolution =
‎            totalStakedPerChoice[NO];
‎
‎        totalPoolAtResolution =
‎            yesPoolAtResolution + noPoolAtResolution;
‎
‎        // Determine winning and losing pools.
‎        if (_winningChoice == YES) {
‎            winnersPoolAtResolution =
‎                yesPoolAtResolution;
‎
‎            losersPoolAtResolution =
‎                noPoolAtResolution;
‎        } else {
‎            winnersPoolAtResolution =
‎                noPoolAtResolution;
‎
‎            losersPoolAtResolution =
‎                yesPoolAtResolution;
‎        }
‎
‎        // No winning participants means refund mode.
‎        if (winnersPoolAtResolution == 0) {
‎            refundMode = true;
‎        }
‎
‎        emit MarketResolved(
‎            _winningChoice,
‎            yesPoolAtResolution,
‎            noPoolAtResolution,
‎            refundMode
‎        );
‎    }
‎
‎    // =============================================================
‎    //                         CLAIM REWARD
‎    // =============================================================
‎
‎    function claim()
‎        external
‎        nonReentrant
‎    {
‎        require(
‎            resolved,
‎            "Market not resolved"
‎        );
‎
‎        require(
‎            !hasClaimed[msg.sender],
‎            "Already claimed"
‎        );
‎
‎        uint256 yesStake = stakes[msg.sender][YES];
‎
‎        uint256 noStake = stakes[msg.sender][NO];
‎
‎        require(
‎            yesStake > 0 || noStake > 0,
‎            "No participation"
‎        );
‎
‎        // Prevent a second claim before transfers.
‎        hasClaimed[msg.sender] = true;
‎
‎        // Clear user positions.
‎        stakes[msg.sender][YES] = 0;
‎
‎        stakes[msg.sender][NO] = 0;
‎
‎        // ---------------------------------------------------------
