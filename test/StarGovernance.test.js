const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StarGovernance", function () {
  let starToken, starStaking, starGovernance;
  let owner, addr1, addr2, addr3;
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

    // Deploy StarGovernance
    const StarGovernance = await ethers.getContractFactory("StarGovernance");
    starGovernance = await StarGovernance.deploy(await starStaking.getAddress());
    await starGovernance.waitForDeployment();

    // Setup: Transfer tokens and fund rewards
    await starToken.transfer(addr1.address, ethers.parseEther("1000"));
    await starToken.transfer(addr2.address, ethers.parseEther("1000"));
    await starToken.approve(await starStaking.getAddress(), REWARD_POOL);
    await starStaking.fundRewards(REWARD_POOL);

    // Users stake tokens
    await starToken.connect(addr1).approve(await starStaking.getAddress(), STAKE_AMOUNT);
    await starStaking.connect(addr1).stake(STAKE_AMOUNT);

    await starToken.connect(addr2).approve(await starStaking.getAddress(), STAKE_AMOUNT);
    await starStaking.connect(addr2).stake(STAKE_AMOUNT);
  });

  describe("Deployment", function () {
    it("Should set correct owner", async function () {
      expect(await starGovernance.owner()).to.equal(owner.address);
    });

    it("Should fail with zero address staking", async function () {
      const StarGovernance = await ethers.getContractFactory("StarGovernance");
      await expect(
        StarGovernance.deploy(ethers.ZeroAddress)
      ).to.be.revertedWith("StarGovernance: Invalid staking address");
    });
  });

  describe("CreateProposal", function () {
    it("Should create proposal correctly", async function () {
      const newRate = 15;
      await starGovernance.createProposal(newRate);

      const proposal = await starGovernance.currentProposal();
      expect(proposal.newRewardRate).to.equal(newRate);
      expect(proposal.executed).to.equal(false);
    });

    it("Should fail if rate exceeds 100%", async function () {
      await expect(
        starGovernance.createProposal(101)
      ).to.be.revertedWith("StarGovernance: Reward rate cannot exceed 100%");
    });

    it("Should fail if not owner", async function () {
      await expect(
        starGovernance.connect(addr1).createProposal(15)
      ).to.be.revertedWith("StarGovernance: Caller is not the owner");
    });

    it("Should fail if active proposal exists", async function () {
      await starGovernance.createProposal(15);

      await expect(
        starGovernance.createProposal(20)
      ).to.be.revertedWith("StarGovernance: Active proposal exists");
    });
  });

  describe("Vote", function () {
    beforeEach(async function () {
      await starGovernance.createProposal(15);
    });

    it("Should vote for proposal", async function () {
      await starGovernance.connect(addr1).vote(true);

      const proposal = await starGovernance.currentProposal();
      expect(proposal.votesFor).to.equal(STAKE_AMOUNT);
    });

    it("Should vote against proposal", async function () {
      await starGovernance.connect(addr1).vote(false);

      const proposal = await starGovernance.currentProposal();
      expect(proposal.votesAgainst).to.equal(STAKE_AMOUNT);
    });

    it("Should fail if already voted", async function () {
      await starGovernance.connect(addr1).vote(true);

      await expect(
        starGovernance.connect(addr1).vote(false)
      ).to.be.revertedWith("StarGovernance: Voter has already voted");
    });

    it("Should fail if no active stake", async function () {
      await expect(
        starGovernance.connect(addr3).vote(true)
      ).to.be.revertedWith("StarGovernance: Voter must have active stake");
    });

    it("Should emit Voted event", async function () {
      await expect(starGovernance.connect(addr1).vote(true))
        .to.emit(starGovernance, "Voted");
    });
  });

  describe("ExecuteProposal", function () {
    beforeEach(async function () {
      await starGovernance.createProposal(15);
      await starGovernance.connect(addr1).vote(true); // Vote for
      await starGovernance.connect(addr2).vote(false); // Vote against
    });

    it("Should fail if voting still active", async function () {
      await expect(
        starGovernance.executeProposal()
      ).to.be.revertedWith("StarGovernance: Voting still active");
    });

    it("Should execute proposal after voting ends", async function () {
      // Fast forward time
      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]); // 3 days + 1 second
      await ethers.provider.send("hardhat_mine", ["0x1"]);

      await starGovernance.executeProposal();

      const proposal = await starGovernance.currentProposal();
      expect(proposal.executed).to.equal(true);
    });
  });

  describe("ResetVotes", function () {
    beforeEach(async function () {
      await starGovernance.createProposal(15);
      await starGovernance.connect(addr1).vote(true);
    });

    it("Should reset votes for users", async function () {
      await starGovernance.resetVotes([addr1.address]);

      // User should be able to vote again
      await expect(starGovernance.connect(addr1).vote(false)).to.not.be.reverted;
    });

    it("Should fail if not owner", async function () {
      await expect(
        starGovernance.connect(addr1).resetVotes([addr1.address])
      ).to.be.revertedWith("StarGovernance: Caller is not the owner");
    });
  });

  describe("TransferOwnership", function () {
    it("Should transfer ownership", async function () {
      await starGovernance.transferOwnership(addr1.address);
      expect(await starGovernance.owner()).to.equal(addr1.address);
    });

    it("Should fail if new owner is zero address", async function () {
      await expect(
        starGovernance.transferOwnership(ethers.ZeroAddress)
      ).to.be.revertedWith("StarGovernance: Invalid new owner address");
    });
  });
});
