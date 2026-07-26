// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StarToken
 * @dev ERC-20 token implementation using OpenZeppelin
 * - Fixed supply of 10,000,000 STAR tokens
 * - Built-in safe transfer mechanisms
 * - Ownership management
 */
contract StarToken is ERC20, Ownable {
    /**
     * @dev Initialize token with 10M supply and set owner
     */
    constructor() ERC20("Star Token", "STAR") Ownable(msg.sender) {
        // Mint 10 million tokens with 18 decimals
        _mint(msg.sender, 10_000_000 * 10 ** decimals());
    }

    /**
     * @dev Mint new tokens (only owner)
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "StarToken: Cannot mint to zero address");
        require(amount > 0, "StarToken: Amount must be greater than 0");
        _mint(to, amount);
    }

    /**
     * @dev Burn tokens from caller
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external {
        require(amount > 0, "StarToken: Amount must be greater than 0");
        _burn(msg.sender, amount);
    }

    /**
     * @dev Burn tokens from specific address (only owner)
     * @param account Account to burn from
     * @param amount Amount to burn
     */
    function burnFrom(address account, uint256 amount) external onlyOwner {
        require(account != address(0), "StarToken: Cannot burn from zero address");
        require(amount > 0, "StarToken: Amount must be greater than 0");
        _burn(account, amount);
    }
}
