// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract StarStaking {

    IERC20 public starToken;
    address public owner;

    uint256 public rewardRate = 10; // 10% annuel
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

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);
    event RewardsFunded(uint256 amount);
    event RewardRateUpdated(uint256 newRate);
    event LockPeriodUpdated(uint256 newLock);
    event OwnershipTransferred(address newOwner);

    constructor(address _starToken) {
        starToken = IERC20(_starToken);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function fundRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "Invalid amount");
        require(starToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        rewardPool += amount;
        emit RewardsFunded(amount);
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        require(!stakes[msg.sender].active, "Already staking");
        require(amount <= maxStakePerUser, "Exceeds max per user");
        require(totalStaked + amount <= maxTotalStaked, "Exceeds total cap");

        require(starToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

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

        emit Staked(msg.sender, amount);
    }

    function withdraw() external {
        Stake memory userStake = stakes[msg.sender];

        require(userStake.active, "No active stake");
        require(block.timestamp >= userStake.timestamp + lockPeriod, "Tokens still locked");

        uint256 stakingDuration = block.timestamp - userStake.timestamp;
        uint256 reward = (userStake.amount * rewardRate * stakingDuration) / (365 days * 100);

        require(reward <= rewardPool, "Not enough rewards");

        uint256 total = userStake.amount + reward;

        rewardPool -= reward;
        totalStaked -= userStake.amount;
        totalRewardsDistributed += reward;
        totalWithdrawals += 1;

        delete stakes[msg.sender];

        require(starToken.transfer(msg.sender, total), "Transfer failed");

        emit Withdrawn(msg.sender, userStake.amount, reward);
    }

    function updateRewardRate(uint256 newRate) external onlyOwner {
        rewardRate = newRate;
        emit RewardRateUpdated(newRate);
    }

    function updateLockPeriod(uint256 newLock) external onlyOwner {
        lockPeriod = newLock;
        emit LockPeriodUpdated(newLock);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
        emit OwnershipTransferred(newOwner);
    }
}