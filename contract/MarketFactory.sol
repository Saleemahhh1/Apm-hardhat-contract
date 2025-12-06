
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./PredictionMarket.sol";

contract MarketFactory is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address[] public allMarkets;
    mapping(address => address[]) public userMarkets;

    IERC20 public token;              // APM token
    uint256 public constant CREATION_FEE = 100 * 10**18; // 100 APM (18 decimals)
    uint256 public rewardPool;
    address public treasury;          // fee receiver / treasury for market fees
    uint256 public defaultFeeBps = 200; // 2% default fee per market

    event MarketCreated(address indexed marketAddress, string question, address indexed creator);
    event RewardDistributed(address indexed market, uint256 amount);
    event RewardPoolIncreased(uint256 newBalance);

    constructor(address _token, address _treasury) {
        require(_token != address(0), "token zero");
        require(_treasury != address(0), "treasury zero");
        token = IERC20(_token);
        treasury = _treasury;
    }

    /// @notice create a market, charge creation fee and add to rewardPool
    function createMarket(
        string memory _question, 
        uint256 _deadline, 
        uint256 _feeBps
    ) external nonReentrant {
        require(_deadline > block.timestamp, "deadline must be future");

        // collect creation fee
        token.safeTransferFrom(msg.sender, address(this), CREATION_FEE);

        // add portion to rewardPool (80%)
        uint256 poolShare = (CREATION_FEE * 80) / 100;
        rewardPool += poolShare;
        emit RewardPoolIncreased(rewardPool);

        // remainder goes to treasury (20%)
        uint256 feeShare = CREATION_FEE - poolShare;
        if (feeShare > 0) token.safeTransfer(treasury, feeShare);

        // create market
        PredictionMarket market = new PredictionMarket(
            address(token),
            _question,
            _deadline,
            address(this),
            _feeBps == 0 ? defaultFeeBps : _feeBps,
            treasury
        );

        allMarkets.push(address(market));
        userMarkets[msg.sender].push(address(market));

        emit MarketCreated(address(market), _question, msg.sender);
    }

    /// @notice called by market to request reward distribution
    function distributeReward(address _market, uint256 _amount) external nonReentrant {
        require(msg.sender == _market, "Only market can request reward");
        require(_amount <= rewardPool, "Not enough in pool");
        rewardPool -= _amount;
        token.safeTransfer(_market, _amount);
        emit RewardDistributed(_market, _amount);
    }

    // view helpers
    function getAllMarkets() external view returns (address[] memory) {
        return allMarkets;
    }

    function getUserMarkets(address _user) external view returns (address[] memory) {
        return userMarkets[_user];
    }

    function getRewardPool() external view returns (uint256) {
        return rewardPool;
    }

    // admin helpers
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "zero");
        treasury = _treasury;
    }

    function setDefaultFee(uint256 _bps) external onlyOwner {
        defaultFeeBps = _bps;
    }
}
