// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStarStaking {
    function stakes(address user) external view returns (uint256 amount, uint256 timestamp, bool active);
    function totalStaked() external view returns (uint256);
    function updateRewardRate(uint256 newRate) external;
}

/**
 * @title StarGovernance
 * @dev Governance contract for voting on protocol parameters
 */
contract StarGovernance {

    IStarStaking public stakingContract;
    address public owner;

    struct Proposal {
        uint256 newRewardRate;
        uint256 endTime;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        uint256 createdAt;
    }

    uint256 public proposalCount = 0;
    Proposal public currentProposal;

    mapping(address => bool) public hasVoted;
    mapping(uint256 => Proposal) public proposals;

    event ProposalCreated(uint256 indexed proposalId, uint256 newRate, uint256 endTime);
    event Voted(address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, uint256 newRate, bool passed);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    constructor(address _stakingAddress) {
        require(_stakingAddress != address(0), "StarGovernance: Invalid staking address");
        stakingContract = IStarStaking(_stakingAddress);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "StarGovernance: Caller is not the owner");
        _;
    }

    /**
     * @dev Create a new proposal
     * @param _newRewardRate Proposed new reward rate
     */
    function createProposal(uint256 _newRewardRate) external onlyOwner {
        require(_newRewardRate <= 100, "StarGovernance: Reward rate cannot exceed 100%");
        require(currentProposal.endTime < block.timestamp || currentProposal.executed, "StarGovernance: Active proposal exists");

        // Reset voting mapping for all previous voters
        // Note: In production, consider using a more gas-efficient approach
        
        uint256 proposalId = proposalCount;
        proposalCount++;

        currentProposal = Proposal({
            newRewardRate: _newRewardRate,
            endTime: block.timestamp + 3 days,
            votesFor: 0,
            votesAgainst: 0,
            executed: false,
            createdAt: block.timestamp
        });

        proposals[proposalId] = currentProposal;

        // Clear previous votes
        hasVoted[msg.sender] = false; // Reset for next proposal

        emit ProposalCreated(proposalId, _newRewardRate, currentProposal.endTime);
    }

    /**
     * @dev Vote on current proposal
     * @param support True to vote for, false to vote against
     */
    function vote(bool support) external {
        require(block.timestamp < currentProposal.endTime, "StarGovernance: Voting period has ended");
        require(!hasVoted[msg.sender], "StarGovernance: Voter has already voted");

        (uint256 amount,, bool active) = stakingContract.stakes(msg.sender);
        require(active && amount > 0, "StarGovernance: Voter must have active stake");

        hasVoted[msg.sender] = true;

        if (support) {
            currentProposal.votesFor += amount;
        } else {
            currentProposal.votesAgainst += amount;
        }

        emit Voted(msg.sender, support, amount);
    }

    /**
     * @dev Execute proposal after voting period ends
     */
    function executeProposal() external {
        require(block.timestamp >= currentProposal.endTime, "StarGovernance: Voting still active");
        require(!currentProposal.executed, "StarGovernance: Proposal already executed");

        uint256 total = stakingContract.totalStaked();
        require(total > 0, "StarGovernance: No active stakers");

        currentProposal.executed = true;
        bool passed = currentProposal.votesFor > currentProposal.votesAgainst;

        if (passed) {
            stakingContract.updateRewardRate(currentProposal.newRewardRate);
        }

        emit ProposalExecuted(proposalCount - 1, currentProposal.newRewardRate, passed);
    }

    /**
     * @dev Reset votes for next proposal (called by createProposal)
     */
    function resetVotes(address[] calldata voters) external onlyOwner {
        for (uint256 i = 0; i < voters.length; i++) {
            hasVoted[voters[i]] = false;
        }
    }

    /**
     * @dev Transfer ownership
     * @param newOwner Address of new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "StarGovernance: Invalid new owner address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
