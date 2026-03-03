// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract StarAirdrop {

    address public owner;
    IERC20 public starToken;
    uint256 public maxRecipients = 100;

    event AirdropExecuted(uint256 totalRecipients, uint256 totalAmount);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    constructor(address _starToken) {
        owner = msg.sender;
        starToken = IERC20(_starToken);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    function airdrop(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {

        require(recipients.length == amounts.length, "Length mismatch");
        require(recipients.length <= maxRecipients, "Too many recipients");

        uint256 totalSent;

        for (uint256 i = 0; i < recipients.length; i++) {
            starToken.transferFrom(owner, recipients[i], amounts[i]);
            totalSent += amounts[i];
        }

        emit AirdropExecuted(recipients.length, totalSent);
    }

    function changeOwner(address newOwner) external onlyOwner {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function rescueTokens(address tokenAddress, uint256 amount) external onlyOwner {
        IERC20(tokenAddress).transfer(owner, amount);
    }
}

