// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./PredictionMarket.sol";

contract MarketFactory is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // =============================================================
    //                         CONFIGURATION
    // =============================================================

    IERC20 public immutable token;
    address public treasury;

    uint256 public constant CREATION_FEE = 100 * 10**18;
    uint256 public constant MAX_FEE_BPS = 1000;

    uint256 public defaultFeeBps = 200;

    // =============================================================
    //                          MARKET DATA
    // =============================================================

    address[] public allMarkets;
    mapping(address => address[]) public userMarkets;
    mapping(address => bool) public isMarket;

    // =============================================================
    //                             EVENTS
    // =============================================================

    event MarketCreated(
        address indexed marketAddress,
        string question,
        address indexed creator,
        uint256 deadline,
        uint256 feeBps
    );

    event MarketResolved(
        address indexed marketAddress,
        uint8 indexed winningChoice,
        address indexed resolver
    );

    event CreationFeeCollected(
        address indexed creator,
        address indexed treasury,
        uint256 amount
    );

    event TreasuryUpdated(
        address indexed previousTreasury,
        address indexed newTreasury
    );

    event DefaultFeeUpdated(
        uint256 previousFeeBps,
        uint256 newFeeBps
    );

    // =============================================================
    //                           CONSTRUCTOR
    // =============================================================

    constructor(address _token, address _treasury) Ownable(msg.sender) {
        require(_token != address(0), "Token zero");
        require(_token.code.length > 0, "Invalid token contract");
        require(_treasury != address(0), "Treasury zero");

        token = IERC20(_token);
        treasury = _treasury;
    }

    // =============================================================
    //                         CREATE MARKET
    // =============================================================

    function createMarket(
        string memory _question,
        uint256 _deadline,
        uint256 _feeBps
    )
        external
        nonReentrant
        returns (address marketAddress)
    {
        require(bytes(_question).length > 0, "Question required");
        require(_deadline > block.timestamp, "Invalid deadline");

        uint256 effectiveFeeBps =
            _feeBps == 0 ? defaultFeeBps : _feeBps;

        require(effectiveFeeBps <= MAX_FEE_BPS, "Fee exceeds maximum");

        // Collect the fixed creation fee.
        // Assumes the APM token uses 18 decimals.
        uint256 balanceBefore = token.balanceOf(address(this));

        token.safeTransferFrom(msg.sender, address(this), CREATION_FEE);

        uint256 balanceAfter = token.balanceOf(address(this));

        require(
            balanceAfter >= balanceBefore &&
            balanceAfter - balanceBefore == CREATION_FEE,
            "Unsupported token transfer"
        );

        // The full creation fee goes to the treasury.
        token.safeTransfer(treasury, CREATION_FEE);

        emit CreationFeeCollected(msg.sender, treasury, CREATION_FEE);

        PredictionMarket market = new PredictionMarket(
            address(token),
            _question,
            _deadline,
            address(this),
            effectiveFeeBps,
            treasury,
            msg.sender
        );

        marketAddress = address(market);

        isMarket[marketAddress] = true;
        allMarkets.push(marketAddress);
        userMarkets[msg.sender].push(marketAddress);

        emit MarketCreated(
            marketAddress,
            _question,
            msg.sender,
            _deadline,
            effectiveFeeBps
        );
    }

    // =============================================================
    //                        RESOLVE MARKET
    // =============================================================

    function resolveMarket(address _market, uint8 _winningChoice) external {
        require(isMarket[_market], "Unknown market");

        PredictionMarket market = PredictionMarket(_market);

        // The market's current owner or the factory owner may resolve it.
        require(
            msg.sender == market.owner() || msg.sender == owner(),
            "Not authorized"
        );

        // PredictionMarket checks deadline, outcome, and onlyFactory.
        market.setResult(_winningChoice);

        emit MarketResolved(_market, _winningChoice, msg.sender);
    }

    // =============================================================
    //                         ADMIN SETTINGS
    // =============================================================

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Treasury zero");

        address previousTreasury = treasury;
        treasury = _treasury;

        emit TreasuryUpdated(previousTreasury, _treasury);
    }

    function setDefaultFee(uint256 _bps) external onlyOwner {
        require(_bps <= MAX_FEE_BPS, "Fee exceeds maximum");

        uint256 previousFeeBps = defaultFeeBps;
        defaultFeeBps = _bps;

        emit DefaultFeeUpdated(previousFeeBps, _bps);
    }

    // =============================================================
    //                         VIEW FUNCTIONS
    // =============================================================

    function getAllMarkets() external view returns (address[] memory) {
        return allMarkets;
    }

    function getUserMarkets(address _user)
        external
        view
        returns (address[] memory)
    {
        return userMarkets[_user];
    }

    function getMarketCount() external view returns (uint256) {
        return allMarkets.length;
    }
}

