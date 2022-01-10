//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/iN0N3DAO.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * The process for voting is done as following:
 * (1) `Owner` queue(address proposalAddress, uint256 fee) a proposal. `Owner` can discard() while queuing
 * (2) `Owner` pushIntoVoting(uint256 proposalId) => Proposal is under community voting
 *  the call is valid if block.number > {`currentProposal.lockUntil` + `waitingForBallotAndEnforce`}
 *  hence set new currentProposal
 * (3) `CommunityMember` yes() (then no()) required block.number < `currentProposal.lockUntil`
 * (4) `Owner` enforce() to evaluate currentProposal.state to ballotCall() and execute()
 */
contract N0N3DAO {
  using SafeMath for uint256;
  struct ProposalInfo {
    address proposalAddress;
    uint256 power;
    uint256 startLockAt;
    uint256 noOfBlockWithinActivePeriod;
    uint256 lockUntil;
    bool executed;
    ProposalState state;
    mapping (address => uint8) supporters;
    address owner;
    uint nextProposalId;
  }
  uint256 totalProposal;
  event VoteCasted (address indexed, bool option, uint256);
  mapping (uint => ProposalInfo) proposals;
  enum ProposalState {
    WAITING, VOTING, FAILED, PASSED, EXECUTED, FAILEDTOEXECUTE
  }
  address public votingTokenAddress;
  uint256 public currentProposalId;
  uint256 public newestProposalId;
  // feePerBlockWithinActivePeriod: fee per block in active period (the time within voting session)
  uint256 public feePerBlockWithinActivePeriod;
  uint256 public minProposalFee;
  // maxNoOfBlockActivePeriod: maximum number of block within an active period
  uint256 public maxNoOfBlockWithinActivePeriod;

  constructor(address votingTokenAddress_){
    votingTokenAddress = votingTokenAddress_;
    currentProposalId = 0;
    totalProposal = 0;
    uint8 decimal = ERC20(votingTokenAddress).decimals();
    if(decimal < 4){
      feePerBlockWithinActivePeriod = 1;
    }else{
      feePerBlockWithinActivePeriod = decimal/1e4;
    }
  }

  function queue(address proposalAddress, uint proposalFee) external returns(uint proposalId){
    require(proposalFee > minProposalFee, "N0N3DAO: not enough fee");
    if(proposalFee > maxNoOfBlockWithinActivePeriod.mul(feePerBlockWithinActivePeriod)){
      IERC20(votingTokenAddress).transfer(address(this), proposalFee.sub(maxNoOfBlockWithinActivePeriod.mul(feePerBlockWithinActivePeriod)));
    }else{
      IERC20(votingTokenAddress).transfer(address(this), proposalFee);
    }
    uint256 noOfBlockWithinActivePeriod = proposalFee.div(feePerBlockWithinActivePeriod);
    uint256 proposalId = totalProposal + 1;
    proposals[proposalId] = ProposalInfo({
      proposalAddress: proposalAddress,
      power: 0,
      startLockAt: 0,
      noOfBlockWithinActivePeriod: noOfBlockWithinActivePeriod,
      lockUntil: 0,
      executed: false,
      state: ProposalState.WAITING,
      owner: msg.sender,
      nextProposalId: 0
    });
    newestProposalId = proposalId;
    return newestProposalId;
  }

  /**
  * a successful voted proposal will be waited to execute within this timeframe
  * 
  * after this
   */
  uint public waitingForRatify;

  /*
  * can only go through by a proposal
  */
  function setVotingToken(address votingTokenAddress_) internal{
    votingTokenAddress = votingTokenAddress_;
  }

  function setFeePerBlock(uint feePerBlock_) internal {
    feePerBlockWithinActivePeriod = feePerBlock_;
  }

  function yes() external {
    _beforeVote();
    uint256 votingPower = IERC20(votingTokenAddress).balanceOf(msg.sender);
    require(votingPower > 0, "N0N3DAO: You must have some token to vote");
    proposals[currentProposalId].supporters[msg.sender] = 1;
    proposals[currentProposalId].power += votingPower;
    _afterVote(msg.sender, true, votingPower);
  }
  
  function no() external {
    _beforeVote();
    require(proposals[currentProposalId].supporters[msg.sender] == 1, "N0N3DAO: You didn't cast a vote");
    uint256 votingPower = IERC20(votingTokenAddress).balanceOf(msg.sender);
    proposals[currentProposalId].supporters[msg.sender] = 0;
    proposals[currentProposalId].power -= votingPower;
    _afterVote(msg.sender, false, votingPower);
  }

  function _beforeVote() view private {
    require(currentProposalId > 0, "N0N3DAO: There is no proposal to vote");
    require(proposals[currentProposalId].lockUntil > block.number, "N0N3DAO: current proposal is expired");
  }

  function _afterVote(address voter, bool option, uint256 votingPower) private {
    emit VoteCasted(voter, option, votingPower);
  }

  /*
  * Ballot will be called after the lock is released
  * - An invalid vote will trigger _ballotCall
  * - Next 
  */
  function _ballotCall() private {
    
    ProposalInfo storage info = proposals[currentProposalId];
    
  }

  /**
  * everyone can enforce
   */
  function ratify() external {
    
    // enforce the current proposal
  }

  function calculateProposalFee(uint howManyDays) external view returns (uint) {
    return feePerBlockWithinActivePeriod * howManyDays * 28800;
  }


}