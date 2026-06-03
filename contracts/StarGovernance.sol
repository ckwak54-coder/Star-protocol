// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IStarStaking {
    function stakes(address user) external view returns (uint256 amount, uint256 timestamp, bool active);
    function totalStaked() external view returns (uint256);
    function updateRewardRate(uint256 newRate) external;
}

/**
 * @title StarGovernance
 * @dev Governance contract for voting on protocol parameters
 * - Time-locked proposals
 * - Vote tracking with reset capability
 * - Safe execution with reentrancy guard
 */
contract StarGovernance is Ownable, ReentrancyGuard {

    IStarStaking public immutable stakingContract;

    struct Proposal {
        uint256 newRewardRate;
        uint256 endTime;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        uint256 createdAt;
    }

    uint256 public proposalCount = 0;
    uint256 public votingDuration = 3 days;

    Proposal public currentProposal;

    mapping(address => bool) public hasVoted;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public proposalVotes;

    event ProposalCreated(uint256 indexed proposalId, uint256 newRate, uint256 endTime);
    event Voted(address indexed voter, uint256 indexed proposalId, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, uint256 newRate, bool passed);
    event VotingDurationUpdated(uint256 oldDuration, uint256 newDuration);

    constructor(address _stakingAddress) Ownable(msg.sender) {
        require(_stakingAddress != address(0), "StarGovernance: Invalid staking address");
        stakingContract = IStarStaking(_stakingAddress);
    }

    /**
     * @dev Create a new proposal
     * @param _newRewardRate Proposed new reward rate
     */
    function createProposal(uint256 _newRewardRate) external onlyOwner {
        require(_newRewardRate <= 100, "StarGovernance: Reward rate cannot exceed 100%");
        require(
            currentProposal.endTime < block.timestamp || currentProposal.executed,
            "StarGovernance: Active proposal exists"
        );

        uint256 proposalId = proposalCount;
        proposalCount++;

        currentProposal = Proposal({
            newRewardRate: _newRewardRate,
            endTime: block.timestamp + votingDuration,
            votesFor: 0,
            votesAgainst: 0,
            executed: false,
            createdAt: block.timestamp
        });

        proposals[proposalId] = currentProposal;

        emit ProposalCreated(proposalId, _newRewardRate, currentProposal.endTime);
    }

    /**
     * @dev Vote on current proposal
     * @param support True to vote for, false to vote against
     */
    function vote(bool support) external nonReentrant {
        require(block.timestamp < currentProposal.endTime, "StarGovernance: Voting period has ended");
        require(!hasVoted[msg.sender], "StarGovernance: Voter has already voted");

        (uint256 amount,, bool active) = stakingContract.stakes(msg.sender);
        require(active && amount > 0, "StarGovernance: Voter must have active stake");

        hasVoted[msg.sender] = true;
        proposalVotes[proposalCount - 1][msg.sender] = true;

        if (support) {
            currentProposal.votesFor += amount;
        } else {
            currentProposal.votesAgainst += amount;
        }

        emit Voted(msg.sender, proposalCount - 1, support, amount);
    }

    /**
     * @dev Execute proposal after voting period ends
     */
    function executeProposal() external nonReentrant {
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
     * @dev Reset votes for specific users (for next proposal)
     * @param voters Array of voter addresses to reset
     */
    function resetVotes(address[] calldata voters) external onlyOwner {
        for (uint256 i = 0; i < voters.length; i++) {
            require(voters[i] != address(0), "StarGovernance: Invalid voter address");
            hasVoted[voters[i]] = false;
        }
    }

    /**
     * @dev Update voting duration
     * @param newDuration New voting duration in seconds
     */
    function updateVotingDuration(uint256 newDuration) external onlyOwner {
        require(newDuration > 0, "StarGovernance: Duration must be greater than 0");
        uint256 oldDuration = votingDuration;
        votingDuration = newDuration;
        emit VotingDurationUpdated(oldDuration, newDuration);
    }

    /**
     * @dev Check if user has voted on proposal
     * @param proposalId Proposal ID
     * @param voter Voter address
     */
    function hasVotedOnProposal(uint256 proposalId, address voter) external view returns (bool) {
        return proposalVotes[proposalId][voter];
    }
}
