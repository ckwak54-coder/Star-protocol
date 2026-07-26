const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StarAirdrop", function () {
  let starToken, starAirdrop;
  let owner, addr1, addr2, addr3, addr4;
  const AIRDROP_AMOUNT = ethers.parseEther("100");

  beforeEach(async function () {
    [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();

    // Deploy StarToken
    const StarToken = await ethers.getContractFactory("StarToken");
    starToken = await StarToken.deploy();
    await starToken.waitForDeployment();

    // Deploy StarAirdrop
    const StarAirdrop = await ethers.getContractFactory("StarAirdrop");
    starAirdrop = await StarAirdrop.deploy(await starToken.getAddress());
    await starAirdrop.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set correct owner", async function () {
      expect(await starAirdrop.owner()).to.equal(owner.address);
    });

    it("Should set correct token address", async function () {
      expect(await starAirdrop.starToken()).to.equal(await starToken.getAddress());
    });

    it("Should fail with zero address token", async function () {
      const StarAirdrop = await ethers.getContractFactory("StarAirdrop");
      await expect(
        StarAirdrop.deploy(ethers.ZeroAddress)
      ).to.be.revertedWith("StarAirdrop: Invalid token address");
    });
  });

  describe("Airdrop", function () {
    it("Should execute airdrop correctly", async function () {
      const recipients = [addr1.address, addr2.address];
      const amounts = [AIRDROP_AMOUNT, AIRDROP_AMOUNT];

      await starToken.approve(await starAirdrop.getAddress(), AIRDROP_AMOUNT * 2n);
      await starAirdrop.airdrop(recipients, amounts);

      expect(await starToken.balanceOf(addr1.address)).to.equal(AIRDROP_AMOUNT);
      expect(await starToken.balanceOf(addr2.address)).to.equal(AIRDROP_AMOUNT);
    });

    it("Should fail if arrays length mismatch", async function () {
      const recipients = [addr1.address, addr2.address];
      const amounts = [AIRDROP_AMOUNT];

      await starToken.approve(await starAirdrop.getAddress(), AIRDROP_AMOUNT);

      await expect(
        starAirdrop.airdrop(recipients, amounts)
      ).to.be.revertedWith("StarAirdrop: Length mismatch");
    });

    it("Should fail if exceeds max recipients", async function () {
      const recipients = new Array(101).fill(addr1.address);
      const amounts = new Array(101).fill(AIRDROP_AMOUNT);

      await starToken.approve(await starAirdrop.getAddress(), ethers.parseEther("10100"));

      await expect(
        starAirdrop.airdrop(recipients, amounts)
      ).to.be.revertedWith("StarAirdrop: Too many recipients");
    });

    it("Should fail if empty recipients list", async function () {
      const recipients = [];
      const amounts = [];

      await expect(
        starAirdrop.airdrop(recipients, amounts)
      ).to.be.revertedWith("StarAirdrop: Empty recipients list");
    });

    it("Should fail if recipient is zero address", async function () {
      const recipients = [ethers.ZeroAddress];
      const amounts = [AIRDROP_AMOUNT];

      await starToken.approve(await starAirdrop.getAddress(), AIRDROP_AMOUNT);

      await expect(
        starAirdrop.airdrop(recipients, amounts)
      ).to.be.revertedWith("StarAirdrop: Invalid recipient address");
    });

    it("Should fail if amount is zero", async function () {
      const recipients = [addr1.address];
      const amounts = [0];

      await starToken.approve(await starAirdrop.getAddress(), AIRDROP_AMOUNT);

      await expect(
        starAirdrop.airdrop(recipients, amounts)
      ).to.be.revertedWith("StarAirdrop: Amount must be greater than 0");
    });

    it("Should emit AirdropExecuted event", async function () {
      const recipients = [addr1.address, addr2.address];
      const amounts = [AIRDROP_AMOUNT, AIRDROP_AMOUNT];

      await starToken.approve(await starAirdrop.getAddress(), AIRDROP_AMOUNT * 2n);

      await expect(starAirdrop.airdrop(recipients, amounts))
        .to.emit(starAirdrop, "AirdropExecuted");
    });

    it("Should fail if not owner", async function () {
      const recipients = [addr1.address];
      const amounts = [AIRDROP_AMOUNT];

      await expect(
        starAirdrop.connect(addr1).airdrop(recipients, amounts)
      ).to.be.revertedWith("StarAirdrop: Not authorized");
    });
  });

  describe("ChangeOwner", function () {
    it("Should change owner", async function () {
      await starAirdrop.changeOwner(addr1.address);
      expect(await starAirdrop.owner()).to.equal(addr1.address);
    });

    it("Should fail if new owner is zero address", async function () {
      await expect(
        starAirdrop.changeOwner(ethers.ZeroAddress)
      ).to.be.revertedWith("StarAirdrop: Invalid new owner address");
    });
  });

  describe("RescueTokens", function () {
    it("Should rescue tokens", async function () {
      const rescueAmount = ethers.parseEther("1000");
      await starToken.approve(await starAirdrop.getAddress(), rescueAmount);
      await starToken.transfer(await starAirdrop.getAddress(), rescueAmount);

      const initialBalance = await starToken.balanceOf(owner.address);
      await starAirdrop.rescueTokens(await starToken.getAddress(), rescueAmount);
      const finalBalance = await starToken.balanceOf(owner.address);

      expect(finalBalance).to.equal(initialBalance + rescueAmount);
    });

    it("Should fail if amount is zero", async function () {
      await expect(
        starAirdrop.rescueTokens(await starToken.getAddress(), 0)
      ).to.be.revertedWith("StarAirdrop: Amount must be greater than 0");
    });
  });

  describe("UpdateMaxRecipients", function () {
    it("Should update max recipients", async function () {
      const newMax = 200;
      await starAirdrop.updateMaxRecipients(newMax);
      expect(await starAirdrop.maxRecipients()).to.equal(newMax);
    });

    it("Should fail if new max is zero", async function () {
      await expect(
        starAirdrop.updateMaxRecipients(0)
      ).to.be.revertedWith("StarAirdrop: Max recipients must be greater than 0");
    });

    it("Should fail if not owner", async function () {
      await expect(
        starAirdrop.connect(addr1).updateMaxRecipients(200)
      ).to.be.revertedWith("StarAirdrop: Not authorized");
    });
  });
});
