// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStarStaking {
    function stakes(address user) external view returns (uint256 amount, uint256 timestamp, bool active);
    function totalStaked() external view returns (uint256);
    function updateRewardRate(uint256 newRate) external;
}

contract StarGovernance {

    IStarStaking public stakingContract;
    address public owner;

    struct Proposal {
        uint256 newRewardRate;
        uint256 endTime;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
    }

    Proposal public currentProposal;

    mapping(address => bool) public hasVoted;

    event ProposalCreated(uint256 newRate, uint256 endTime);
    event Voted(address voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 newRate);

    constructor(address _stakingAddress) {
        stakingContract = IStarStaking(_stakingAddress);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function createProposal(uint256 _newRewardRate) external onlyOwner {
        require(currentProposal.endTime < block.timestamp || currentProposal.executed, "Active proposal exists");

        currentProposal = Proposal({
            newRewardRate: _newRewardRate,
            endTime: block.timestamp + 3 days,
            votesFor: 0,
            votesAgainst: 0,
            executed: false
        });

        emit ProposalCreated(_newRewardRate, currentProposal.endTime);
    }

    function vote(bool support) external {
        require(block.timestamp < currentProposal.endTime, "Voting ended");
        require(!hasVoted[msg.sender], "Already voted");

        (uint256 amount,, bool active) = stakingContract.stakes(msg.sender);
        require(active && amount > 0, "No active stake");

        hasVoted[msg.sender] = true;

        if (support) {
            currentProposal.votesFor += amount;
        } else {
            currentProposal.votesAgainst += amount;
        }

        emit Voted(msg.sender, support, amount);
    }

    function executeProposal() external {
        require(block.timestamp >= currentProposal.endTime, "Voting still active");
        require(!currentProposal.executed, "Already executed");

        uint256 total = stakingContract.totalStaked();

        require(total > 0, "No stakers");

        if (currentProposal.votesFor > currentProposal.votesAgainst) {
            stakingContract.updateRewardRate(currentProposal.newRewardRate);
        }

        currentProposal.executed = true;

        emit ProposalExecuted(currentProposal.newRewardRate);
    }
}