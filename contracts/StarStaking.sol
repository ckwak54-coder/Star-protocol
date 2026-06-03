// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title StarStaking
 * @dev Staking contract with reward distribution
 * - Uses SafeERC20 for safe token transfers
 * - ReentrancyGuard protects against reentrancy attacks
 * - Configurable rewards and lock periods
 */
contract StarStaking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable starToken;

    uint256 public rewardRate = 10; // 10% annual
    uint256 public rewardPool;
    uint256 public lockPeriod = 7 days;

    uint256 public maxStakePerUser = 1000 * 10**18;
    uint256 public maxTotalStaked = 100_000 * 10**18;

    uint256 public totalStaked;
    uint256 public totalRewardsDistributed;
    uint256 public totalUsersStaked;
    uint256 public totalWithdrawals;

    struct Stake {
        uint256 amount;
        uint256 timestamp;
        bool active;
    }

    mapping(address => Stake) public stakes;
    mapping(address => bool) public hasParticipated;

    event Staked(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward, uint256 timestamp);
    event RewardsFunded(uint256 amount, address indexed funder);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event LockPeriodUpdated(uint256 oldLock, uint256 newLock);
    event MaxStakeUpdated(uint256 newMax);
    event MaxTotalStakedUpdated(uint256 newMax);

    constructor(address _starToken) Ownable(msg.sender) {
        require(_starToken != address(0), "StarStaking: Invalid token address");
        starToken = IERC20(_starToken);
    }

    /**
     * @dev Fund the reward pool with tokens
     * @param amount Amount to add to reward pool
     */
    function fundRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "StarStaking: Amount must be greater than 0");
        starToken.safeTransferFrom(msg.sender, address(this), amount);
        rewardPool += amount;
        emit RewardsFunded(amount, msg.sender);
    }

    /**
     * @dev Stake tokens with safety checks and reentrancy protection
     * @param amount Amount to stake
     */
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "StarStaking: Stake amount must be greater than 0");
        require(!stakes[msg.sender].active, "StarStaking: User already has active stake");
        require(amount <= maxStakePerUser, "StarStaking: Stake exceeds maximum per user");
        require(totalStaked + amount <= maxTotalStaked, "StarStaking: Total stake cap exceeded");

        starToken.safeTransferFrom(msg.sender, address(this), amount);

        stakes[msg.sender] = Stake({
            amount: amount,
            timestamp: block.timestamp,
            active: true
        });

        totalStaked += amount;

        if (!hasParticipated[msg.sender]) {
            hasParticipated[msg.sender] = true;
            totalUsersStaked += 1;
        }

        emit Staked(msg.sender, amount, block.timestamp);
    }

    /**
     * @dev Withdraw staked tokens and claim rewards
     */
    function withdraw() external nonReentrant {
        Stake memory userStake = stakes[msg.sender];

        require(userStake.active, "StarStaking: No active stake found");
        require(block.timestamp >= userStake.timestamp + lockPeriod, "StarStaking: Tokens still locked");

        uint256 stakingDuration = block.timestamp - userStake.timestamp;
        uint256 reward = (userStake.amount * rewardRate * stakingDuration) / (365 days * 100);

        require(reward <= rewardPool, "StarStaking: Insufficient rewards in pool");

        uint256 total = userStake.amount + reward;

        rewardPool -= reward;
        totalStaked -= userStake.amount;
        totalRewardsDistributed += reward;
        totalWithdrawals += 1;

        delete stakes[msg.sender];

        starToken.safeTransfer(msg.sender, total);

        emit Withdrawn(msg.sender, userStake.amount, reward, block.timestamp);
    }

    /**
     * @dev Update reward rate (only owner)
     * @param newRate New reward rate (0-100)
     */
    function updateRewardRate(uint256 newRate) external onlyOwner {
        require(newRate <= 100, "StarStaking: Reward rate cannot exceed 100%");
        uint256 oldRate = rewardRate;
        rewardRate = newRate;
        emit RewardRateUpdated(oldRate, newRate);
    }

    /**
     * @dev Update lock period (only owner)
     * @param newLock New lock period in seconds
     */
    function updateLockPeriod(uint256 newLock) external onlyOwner {
        require(newLock > 0, "StarStaking: Lock period must be greater than 0");
        uint256 oldLock = lockPeriod;
        lockPeriod = newLock;
        emit LockPeriodUpdated(oldLock, newLock);
    }

    /**
     * @dev Update max stake per user
     * @param newMax New maximum stake per user
     */
    function updateMaxStakePerUser(uint256 newMax) external onlyOwner {
        require(newMax > 0, "StarStaking: Max stake must be greater than 0");
        maxStakePerUser = newMax;
        emit MaxStakeUpdated(newMax);
    }

    /**
     * @dev Update max total staked
     * @param newMax New maximum total staked
     */
    function updateMaxTotalStaked(uint256 newMax) external onlyOwner {
        require(newMax > 0, "StarStaking: Max total staked must be greater than 0");
        maxTotalStaked = newMax;
        emit MaxTotalStakedUpdated(newMax);
    }

    /**
     * @dev Get user stake information
     * @param user User address
     */
    function getUserStake(address user) external view returns (uint256 amount, uint256 timestamp, bool active) {
        Stake memory userStake = stakes[user];
        return (userStake.amount, userStake.timestamp, userStake.active);
    }

    /**
     * @dev Calculate pending reward for user
     * @param user User address
     */
    function getPendingReward(address user) external view returns (uint256) {
        Stake memory userStake = stakes[user];
        if (!userStake.active) return 0;

        uint256 stakingDuration = block.timestamp - userStake.timestamp;
        return (userStake.amount * rewardRate * stakingDuration) / (365 days * 100);
    }
}
