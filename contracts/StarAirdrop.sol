// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title StarAirdrop
 * @dev Secure airdrop contract with batch distribution
 * - Uses SafeERC20 for safe token transfers
 * - ReentrancyGuard protects against reentrancy
 * - Configurable limits and batch processing
 */
contract StarAirdrop is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable starToken;
    uint256 public maxRecipients = 100;
    uint256 public totalAirdropsExecuted = 0;
    uint256 public totalTokensDistributed = 0;

    event AirdropExecuted(
        uint256 indexed airdropId,
        uint256 totalRecipients,
        uint256 totalAmount,
        uint256 timestamp
    );
    event MaxRecipientsUpdated(uint256 oldMax, uint256 newMax);
    event EmergencyWithdraw(address indexed token, uint256 amount);

    constructor(address _starToken) Ownable(msg.sender) {
        require(_starToken != address(0), "StarAirdrop: Invalid token address");
        starToken = IERC20(_starToken);
    }

    /**
     * @dev Execute airdrop to multiple recipients with safety checks
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to send
     */
    function airdrop(address[] calldata recipients, uint256[] calldata amounts)
        external
        onlyOwner
        nonReentrant
    {
        require(recipients.length == amounts.length, "StarAirdrop: Length mismatch");
        require(recipients.length <= maxRecipients, "StarAirdrop: Too many recipients");
        require(recipients.length > 0, "StarAirdrop: Empty recipients list");

        uint256 totalSent = 0;

        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "StarAirdrop: Invalid recipient address");
            require(amounts[i] > 0, "StarAirdrop: Amount must be greater than 0");

            starToken.safeTransferFrom(msg.sender, recipients[i], amounts[i]);
            totalSent += amounts[i];
        }

        totalAirdropsExecuted += 1;
        totalTokensDistributed += totalSent;

        emit AirdropExecuted(totalAirdropsExecuted, recipients.length, totalSent, block.timestamp);
    }

    /**
     * @dev Execute airdrop with equal amounts to all recipients
     * @param recipients Array of recipient addresses
     * @param amount Amount to send to each recipient
     */
    function airdropEqual(address[] calldata recipients, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        require(recipients.length <= maxRecipients, "StarAirdrop: Too many recipients");
        require(recipients.length > 0, "StarAirdrop: Empty recipients list");
        require(amount > 0, "StarAirdrop: Amount must be greater than 0");

        uint256 totalSent = amount * recipients.length;

        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "StarAirdrop: Invalid recipient address");
            starToken.safeTransferFrom(msg.sender, recipients[i], amount);
        }

        totalAirdropsExecuted += 1;
        totalTokensDistributed += totalSent;

        emit AirdropExecuted(totalAirdropsExecuted, recipients.length, totalSent, block.timestamp);
    }

    /**
     * @dev Update max recipients limit
     * @param newMax New maximum number of recipients
     */
    function updateMaxRecipients(uint256 newMax) external onlyOwner {
        require(newMax > 0, "StarAirdrop: Max recipients must be greater than 0");
        uint256 oldMax = maxRecipients;
        maxRecipients = newMax;
        emit MaxRecipientsUpdated(oldMax, newMax);
    }

    /**
     * @dev Emergency withdrawal of tokens
     * @param token Token address to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner nonReentrant {
        require(token != address(0), "StarAirdrop: Invalid token address");
        require(amount > 0, "StarAirdrop: Amount must be greater than 0");

        IERC20(token).safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(token, amount);
    }

    /**
     * @dev Get airdrop statistics
     */
    function getStats() external view returns (
        uint256 airdropCount,
        uint256 tokensDistributed,
        uint256 maxRecip
    ) {
        return (totalAirdropsExecuted, totalTokensDistributed, maxRecipients);
    }
}
