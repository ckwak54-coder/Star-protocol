const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StarToken", function () {
  let starToken;
  let owner, addr1, addr2, addr3;
  const INITIAL_SUPPLY = ethers.parseEther("10000000"); // 10M tokens

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    const StarToken = await ethers.getContractFactory("StarToken");
    starToken = await StarToken.deploy();
    await starToken.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should have correct name and symbol", async function () {
      expect(await starToken.name()).to.equal("Star Token");
      expect(await starToken.symbol()).to.equal("STAR");
    });

    it("Should have correct decimals", async function () {
      expect(await starToken.decimals()).to.equal(18);
    });

    it("Should assign total supply to owner", async function () {
      expect(await starToken.balanceOf(owner.address)).to.equal(INITIAL_SUPPLY);
    });

    it("Should have correct total supply", async function () {
      expect(await starToken.totalSupply()).to.equal(INITIAL_SUPPLY);
    });
  });

  describe("Transfer", function () {
    it("Should transfer tokens between accounts", async function () {
      const amount = ethers.parseEther("100");
      await starToken.transfer(addr1.address, amount);
      expect(await starToken.balanceOf(addr1.address)).to.equal(amount);
    });

    it("Should fail if sender has insufficient balance", async function () {
      const amount = ethers.parseEther("1000000000"); // More than total supply
      await expect(
        starToken.transfer(addr1.address, amount)
      ).to.be.revertedWith("StarToken: Insufficient balance");
    });

    it("Should fail if transfer to zero address", async function () {
      const amount = ethers.parseEther("100");
      await expect(
        starToken.transfer(ethers.ZeroAddress, amount)
      ).to.be.revertedWith("StarToken: Cannot transfer to zero address");
    });

    it("Should emit Transfer event", async function () {
      const amount = ethers.parseEther("100");
      await expect(starToken.transfer(addr1.address, amount))
        .to.emit(starToken, "Transfer")
        .withArgs(owner.address, addr1.address, amount);
    });
  });

  describe("Approve & Allowance", function () {
    it("Should approve tokens for spending", async function () {
      const amount = ethers.parseEther("100");
      await starToken.approve(addr1.address, amount);
      expect(await starToken.allowance(owner.address, addr1.address)).to.equal(amount);
    });

    it("Should fail if approve zero address", async function () {
      const amount = ethers.parseEther("100");
      await expect(
        starToken.approve(ethers.ZeroAddress, amount)
      ).to.be.revertedWith("StarToken: Cannot approve zero address");
    });

    it("Should emit Approval event", async function () {
      const amount = ethers.parseEther("100");
      await expect(starToken.approve(addr1.address, amount))
        .to.emit(starToken, "Approval")
        .withArgs(owner.address, addr1.address, amount);
    });
  });

  describe("IncreaseAllowance", function () {
    it("Should increase allowance correctly", async function () {
      const amount = ethers.parseEther("100");
      const addedValue = ethers.parseEther("50");

      await starToken.approve(addr1.address, amount);
      await starToken.increaseAllowance(addr1.address, addedValue);

      expect(await starToken.allowance(owner.address, addr1.address)).to.equal(
        amount + addedValue
      );
    });

    it("Should fail if increase allowance for zero address", async function () {
      const addedValue = ethers.parseEther("50");
      await expect(
        starToken.increaseAllowance(ethers.ZeroAddress, addedValue)
      ).to.be.revertedWith("StarToken: Cannot approve zero address");
    });
  });

  describe("DecreaseAllowance", function () {
    it("Should decrease allowance correctly", async function () {
      const amount = ethers.parseEther("100");
      const subtractedValue = ethers.parseEther("30");

      await starToken.approve(addr1.address, amount);
      await starToken.decreaseAllowance(addr1.address, subtractedValue);

      expect(await starToken.allowance(owner.address, addr1.address)).to.equal(
        amount - subtractedValue
      );
    });

    it("Should fail if decreasing below zero", async function () {
      const amount = ethers.parseEther("50");
      const subtractedValue = ethers.parseEther("100");

      await starToken.approve(addr1.address, amount);
      await expect(
        starToken.decreaseAllowance(addr1.address, subtractedValue)
      ).to.be.revertedWith("StarToken: Decreased allowance below zero");
    });
  });

  describe("TransferFrom", function () {
    it("Should transfer tokens on behalf of owner", async function () {
      const amount = ethers.parseEther("100");
      await starToken.approve(addr1.address, amount);

      await starToken.connect(addr1).transferFrom(owner.address, addr2.address, amount);

      expect(await starToken.balanceOf(addr2.address)).to.equal(amount);
      expect(await starToken.allowance(owner.address, addr1.address)).to.equal(0);
    });

    it("Should fail if allowance exceeded", async function () {
      const allowance = ethers.parseEther("50");
      const transferAmount = ethers.parseEther("100");

      await starToken.approve(addr1.address, allowance);
      await expect(
        starToken.connect(addr1).transferFrom(owner.address, addr2.address, transferAmount)
      ).to.be.revertedWith("StarToken: Allowance exceeded");
    });

    it("Should fail if transferFrom zero address", async function () {
      const amount = ethers.parseEther("100");
      await expect(
        starToken.transferFrom(ethers.ZeroAddress, addr1.address, amount)
      ).to.be.revertedWith("StarToken: Cannot transfer from zero address");
    });

    it("Should fail if transferTo zero address", async function () {
      const amount = ethers.parseEther("100");
      await starToken.approve(addr1.address, amount);
      await expect(
        starToken.transferFrom(owner.address, ethers.ZeroAddress, amount)
      ).to.be.revertedWith("StarToken: Cannot transfer to zero address");
    });
  });
});
