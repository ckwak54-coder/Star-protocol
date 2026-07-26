const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StarStaking", function () {
  let starToken, starStaking;
  let owner, addr1, addr2, addr3;
  const INITIAL_SUPPLY = ethers.parseEther("10000000");
  const STAKE_AMOUNT = ethers.parseEther("100");
  const REWARD_POOL = ethers.parseEther("100000");

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    // Deploy StarToken
    const StarToken = await ethers.getContractFactory("StarToken");
    starToken = await StarToken.deploy();
    await starToken.waitForDeployment();

    // Deploy StarStaking
    const StarStaking = await ethers.getContractFactory("StarStaking");
    starStaking = await StarStaking.deploy(await starToken.getAddress());
    await starStaking.waitForDeployment();

    // Transfer tokens to users
    await starToken.transfer(addr1.address, ethers.parseEther("1000"));
    await starToken.transfer(addr2.address, ethers.parseEther("1000"));

    // Fund reward pool
    await starToken.approve(await starStaking.getAddress(), REWARD_POOL);
    await starStaking.fundRewards(REWARD_POOL);
  });

  describe("Deployment", function () {
    it("Should set correct owner", async function () {
      expect(await starStaking.owner()).to.equal(owner.address);
    });

    it("Should set correct token address", async function () {
      expect(await starStaking.starToken()).to.equal(await starToken.getAddress());
    });

    it("Should fail with zero address token", async function () {
      const StarStaking = await ethers.getContractFactory("StarStaking");
      await expect(
        StarStaking.deploy(ethers.ZeroAddress)
      ).to.be.revertedWith("StarStaking: Invalid token address");
    });
  });

  describe("FundRewards", function () {
    it("Should fund rewards correctly", async function () {
      const amount = ethers.parseEther("1000");
      const initialPool = await starStaking.rewardPool();

      await starToken.approve(await starStaking.getAddress(), amount);
      await starStaking.fundRewards(amount);

      expect(await starStaking.rewardPool()).to.equal(initialPool + amount);
    });

    it("Should fail if amount is zero", async function () {
      await expect(
        starStaking.fundRewards(0)
      ).to.be.revertedWith("StarStaking: Amount must be greater than 0");
    });

    it("Should emit RewardsFunded event", async function () {
      const amount = ethers.parseEther("1000");
      await starToken.approve(await starStaking.getAddress(), amount);

      await expect(starStaking.fundRewards(amount))
        .to.emit(starStaking, "RewardsFunded")
        .withArgs(amount, owner.address);
    });
  });

  describe("Stake", function () {
    it("Should stake tokens correctly", async function () {
      await starToken.connect(addr1).approve(await starStaking.getAddress(), STAKE_AMOUNT);
      await starStaking.connect(addr1).stake(STAKE_AMOUNT);

      const stake = await starStaking.stakes(addr1.address);
      expect(stake.amount).to.equal(STAKE_AMOUNT);
      expect(stake.active).to.equal(true);
    });

    it("Should update total staked", async function () {
      await starToken.connect(addr1).approve(await starStaking.getAddress(), STAKE_AMOUNT);
      await starStaking.connect(addr1).stake(STAKE_AMOUNT);

      expect(await starStaking.totalStaked()).to.equal(STAKE_AMOUNT);
    });

    it("Should increment total users staked", async function () {
      await starToken.connect(addr1).approve(await starStaking.getAddress(), STAKE_AMOUNT);
      await starStaking.connect(addr1).stake(STAKE_AMOUNT);

      expect(await starStaking.totalUsersStaked()).to.equal(1);
    });

    it("Should fail if stake amount is zero", async function () {
      await expect(
        starStaking.connect(addr1).stake(0)
      ).to.be.revertedWith("StarStaking: Stake amount must be greater than 0");
    });

    it("Should fail if user already has active stake", async function () {
      await starToken.connect(addr1).approve(await starStaking.getAddress(), STAKE_AMOUNT * 2n);
      await starStaking.connect(addr1).stake(STAKE_AMOUNT);

      await expect(
        starStaking.connect(addr1).stake(STAKE_AMOUNT)
      ).to.be.revertedWith("StarStaking: User already has active stake");
    });

    it("Should fail if stake exceeds max per user", async function () {
      const maxStake = await starStaking.maxStakePerUser();
      const excessAmount = maxStake + ethers.parseEther("1");

      await starToken.transfer(addr1.address, excessAmount);
      await starToken.connect(addr1).approve(await starStaking.getAddress(), excessAmount);

      await expect(
        starStaking.connect(addr1).stake(excessAmount)
      ).to.be.revertedWith("StarStaking: Stake exceeds maximum per user");
    });

    it("Should emit Staked event", async function () {
      await starToken.connect(addr1).approve(await starStaking.getAddress(), STAKE_AMOUNT);

      await expect(starStaking.connect(addr1).stake(STAKE_AMOUNT))
        .to.emit(starStaking, "Staked");
    });
  });

  describe("Withdraw", function () {
    beforeEach(async function () {
      await starToken.connect(addr1).approve(await starStaking.getAddress(), STAKE_AMOUNT);
      await starStaking.connect(addr1).stake(STAKE_AMOUNT);
    });

    it("Should fail if no active stake", async function () {
      await expect(
        starStaking.connect(addr2).withdraw()
      ).to.be.revertedWith("StarStaking: No active stake found");
    });

    it("Should fail if lock period not passed", async function () {
      await expect(
        starStaking.connect(addr1).withdraw()
      ).to.be.revertedWith("StarStaking: Tokens still locked");
    });

    it("Should withdraw after lock period", async function () {
      // Fast forward time
      await ethers.provider.send("hardhat_mine", ["0x1f400"]); // Mine many blocks
      await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60 + 1]); // 7 days + 1 second
      await ethers.provider.send("hardhat_mine", ["0x1"]); // Mine one block

      const initialBalance = await starToken.balanceOf(addr1.address);
      await starStaking.connect(addr1).withdraw();
      const finalBalance = await starToken.balanceOf(addr1.address);

      // Should have at least the stake amount back
      expect(finalBalance).to.be.gte(initialBalance + STAKE_AMOUNT);
    });
  });

  describe("UpdateRewardRate", function () {
    it("Should update reward rate", async function () {
      const newRate = 20;
      await starStaking.updateRewardRate(newRate);
      expect(await starStaking.rewardRate()).to.equal(newRate);
    });

    it("Should fail if rate exceeds 100%", async function () {
      await expect(
        starStaking.updateRewardRate(101)
      ).to.be.revertedWith("StarStaking: Reward rate cannot exceed 100%");
    });

    it("Should fail if not owner", async function () {
      await expect(
        starStaking.connect(addr1).updateRewardRate(20)
      ).to.be.revertedWith("StarStaking: Caller is not the owner");
    });
  });

  describe("UpdateLockPeriod", function () {
    it("Should update lock period", async function () {
      const newLock = 14 * 24 * 60 * 60; // 14 days
      await starStaking.updateLockPeriod(newLock);
      expect(await starStaking.lockPeriod()).to.equal(newLock);
    });

    it("Should fail if lock period is zero", async function () {
      await expect(
        starStaking.updateLockPeriod(0)
      ).to.be.revertedWith("StarStaking: Lock period must be greater than 0");
    });
  });

  describe("TransferOwnership", function () {
    it("Should transfer ownership", async function () {
      await starStaking.transferOwnership(addr1.address);
      expect(await starStaking.owner()).to.equal(addr1.address);
    });

    it("Should fail if new owner is zero address", async function () {
      await expect(
        starStaking.transferOwnership(ethers.ZeroAddress)
      ).to.be.revertedWith("StarStaking: Invalid new owner address");
    });
  });
});
