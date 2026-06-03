// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

/**
 * @title StarAirdrop
 * @dev Airdrop contract for distributing tokens to multiple recipients
 */
contract StarAirdrop {

    address public owner;
    IERC20 public starToken;
    uint256 public maxRecipients = 100;

    event AirdropExecuted(uint256 indexed airdropId, uint256 totalRecipients, uint256 totalAmount);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    constructor(address _starToken) {
        require(_starToken != address(0), "StarAirdrop: Invalid token address");
        owner = msg.sender;
        starToken = IERC20(_starToken);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "StarAirdrop: Not authorized");
        _;
    }

    /**
     * @dev Execute airdrop to multiple recipients
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to send
     */
    function airdrop(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "StarAirdrop: Length mismatch");
        require(recipients.length <= maxRecipients, "StarAirdrop: Too many recipients");
        require(recipients.length > 0, "StarAirdrop: Empty recipients list");

        uint256 totalSent = 0;

        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "StarAirdrop: Invalid recipient address");
            require(amounts[i] > 0, "StarAirdrop: Amount must be greater than 0");
            
            require(starToken.transferFrom(owner, recipients[i], amounts[i]), "StarAirdrop: Transfer failed");
            totalSent += amounts[i];
        }

        emit AirdropExecuted(0, recipients.length, totalSent);
    }

    /**
     * @dev Change owner
     * @param newOwner Address of new owner
     */
    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "StarAirdrop: Invalid new owner address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @dev Rescue tokens (in case of emergency)
     * @param tokenAddress Address of token to rescue
     * @param amount Amount to rescue
     */
    function rescueTokens(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(0), "StarAirdrop: Invalid token address");
        require(amount > 0, "StarAirdrop: Amount must be greater than 0");
        require(IERC20(tokenAddress).transfer(owner, amount), "StarAirdrop: Rescue transfer failed");
    }

    /**
     * @dev Update max recipients limit
     * @param newMax New maximum number of recipients
     */
    function updateMaxRecipients(uint256 newMax) external onlyOwner {
        require(newMax > 0, "StarAirdrop: Max recipients must be greater than 0");
        maxRecipients = newMax;
    }
}
