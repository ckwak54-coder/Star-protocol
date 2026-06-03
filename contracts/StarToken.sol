// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title StarToken
 * @dev ERC-20 token with fixed supply of 10,000,000 STAR
 */
contract StarToken {

    string public name = "Star Token";
    string public symbol = "STAR";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        totalSupply = 10_000_000 * 10**uint256(decimals);
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    /**
     * @dev Transfer tokens to recipient
     * @param to Address of recipient
     * @param value Amount to transfer
     */
    function transfer(address to, uint256 value) public returns (bool) {
        require(to != address(0), "StarToken: Cannot transfer to zero address");
        require(balanceOf[msg.sender] >= value, "StarToken: Insufficient balance");

        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;

        emit Transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Approve spender to transfer tokens on your behalf
     * @param spender Address of spender
     * @param value Amount to approve
     */
    function approve(address spender, uint256 value) public returns (bool) {
        require(spender != address(0), "StarToken: Cannot approve zero address");
        allowance[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Increase allowance (safer than approve)
     * @param spender Address of spender
     * @param addedValue Amount to add to allowance
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        require(spender != address(0), "StarToken: Cannot approve zero address");
        allowance[msg.sender][spender] += addedValue;
        emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
        return true;
    }

    /**
     * @dev Decrease allowance
     * @param spender Address of spender
     * @param subtractedValue Amount to subtract from allowance
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        require(spender != address(0), "StarToken: Cannot approve zero address");
        require(allowance[msg.sender][spender] >= subtractedValue, "StarToken: Decreased allowance below zero");
        allowance[msg.sender][spender] -= subtractedValue;
        emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another
     * @param from Address to transfer from
     * @param to Address to transfer to
     * @param value Amount to transfer
     */
    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(from != address(0), "StarToken: Cannot transfer from zero address");
        require(to != address(0), "StarToken: Cannot transfer to zero address");
        require(balanceOf[from] >= value, "StarToken: Insufficient balance");
        require(allowance[from][msg.sender] >= value, "StarToken: Allowance exceeded");

        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;

        emit Transfer(from, to, value);
        return true;
    }
}
