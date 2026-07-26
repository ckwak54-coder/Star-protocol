// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title StarStaking
 * @dev Staking contract for Star tokens with reward distribution
 */
contract StarStaking {

    IERC20 public starToken;
    address public owner;

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
    event RewardRateUpdated(uint256 newRate);
    event LockPeriodUpdated(uint256 newLock);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    constructor(address _starToken) {
        require(_starToken != address(0), "StarStaking: Invalid token address");
        starToken = IERC20(_starToken);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "StarStaking: Caller is not the owner");
        _;
    }

    /**
     * @dev Fund the reward pool
     * @param amount Amount to add to reward pool
     */
    function fundRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "StarStaking: Amount must be greater than 0");
        require(starToken.transferFrom(msg.sender, address(this), amount), "StarStaking: Reward funding failed");

        rewardPool += amount;
        emit RewardsFunded(amount, msg.sender);
    }

    /**
     * @dev Stake tokens
     * @param amount Amount to stake
     */
    function stake(uint256 amount) external {
        require(amount > 0, "StarStaking: Stake amount must be greater than 0");
        require(!stakes[msg.sender].active, "StarStaking: User already has active stake");
        require(amount <= maxStakePerUser, "StarStaking: Stake exceeds maximum per user");
        require(totalStaked + amount <= maxTotalStaked, "StarStaking: Total stake cap exceeded");

        require(starToken.transferFrom(msg.sender, address(this), amount), "StarStaking: Stake transfer failed");

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
    function withdraw() external {
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

        require(starToken.transfer(msg.sender, total), "StarStaking: Withdrawal transfer failed");

        emit Withdrawn(msg.sender, userStake.amount, reward, block.timestamp);
    }

    /**
     * @dev Update reward rate (only owner)
     * @param newRate New reward rate
     */
    function updateRewardRate(uint256 newRate) external onlyOwner {
        require(newRate <= 100, "StarStaking: Reward rate cannot exceed 100%");
        rewardRate = newRate;
        emit RewardRateUpdated(newRate);
    }

    /**
     * @dev Update lock period (only owner)
     * @param newLock New lock period in seconds
     */
    function updateLockPeriod(uint256 newLock) external onlyOwner {
        require(newLock > 0, "StarStaking: Lock period must be greater than 0");
        lockPeriod = newLock;
        emit LockPeriodUpdated(newLock);
    }

    /**
     * @dev Transfer ownership to new owner
     * @param newOwner Address of new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "StarStaking: Invalid new owner address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @dev Get user stake info
     * @param user Address of user
     */
    function getUserStake(address user) external view returns (uint256 amount, uint256 timestamp, bool active) {
        Stake memory userStake = stakes[user];
        return (userStake.amount, userStake.timestamp, userStake.active);
    }
}
