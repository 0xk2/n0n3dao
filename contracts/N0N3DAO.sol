//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/iN0N3DAO.sol";
import "./types/Proposal.sol";
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
    address addr;
    address owner;

    address currency;
    uint256 paid;
    uint256 power;
    
    uint256 startLockAt;
    uint256 noOfBlockWithinActivePeriod;
    ProposalState state;
    uint256 noOfSupporter;
    
    
    uint256 waitingForRatifyNoOfBlock;

    uint256 next;
    uint256 prev;
  }
  uint256 totalProposal;
  // proposalSupporters[proposalId][supporter] = power
  mapping(uint256 => mapping(address => uint256)) proposalSupporters;
  event VoteCasted (address indexed, bool option, uint256);
  mapping (uint => ProposalInfo) proposals;
  enum ProposalState {
    WAITING, DISCARDED, VOTING, FAILED, PASSED, STARTEXECUTE, EXECUTED, FAILEDTOEXECUTE
  }
  address public votingTokenAddress;
  uint256 public currentProposalId;
  uint256 public newestProposalId;
  // feePerBlockWithinActivePeriod: fee per block in active period (the time within voting session)
  uint256 public feePerBlockWithinActivePeriod;
  uint256 public minProposalFee;
  // maxNoOfBlockActivePeriod: maximum number of block within an active period
  uint256 public maxNoOfBlockWithinActivePeriod;

  bool _raceLock;

  function lockRace() private{
    _raceLock = true;
  }

  function unlockRace() private {
    _raceLock = false;
  }

  event QUEUED(address indexed proposalAddress, address indexed owner, uint256 proposalId);
  event DISCARDED(address indexed proposalAddress, address indexed owner, uint256 proposalId);
  event VOTINGTOKENCHANGE(address indexed oldTokenAddress, address indexed newTokenAddress);
  event FEEPERBLOCKCHANGED(uint256 effectiveAfter, uint256 newFee, uint256 oldFee);
  event ACTIVEPERIODSTARTED(uint256 indexed proposalId, address indexed proposalAddress, address indexed proposalOwner, 
    uint256 startAt, uint256 endAt);

  /**
  * a successful voted proposal will be waited to execute within this timeframe
  * 
  * after this
   */
  uint public waitingForRatifyNoOfBlock;

  modifier onlyDAO() {
    require(msg.sender == address(this), "N0N3DAO: onlyDAO can execute this function");
    _;
  }

  modifier proposalExisted(uint256 proposalId_) {
    require(proposals[proposalId_].addr != address(0), 
      "N0N3DAO: proposal is not existed");
    _;
  }

  modifier noRaceLocked {
    require(_raceLock == false, "N0N3DAO: lock to prevent race condition");
    _;
  }

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
    // 7 day, 15s per block
    waitingForRatifyNoOfBlock = 40320;
  }

  /**
  * Proposal and voting parameters
   */
  function setVotingToken(address votingTokenAddress_) external onlyDAO {
    require(votingTokenAddress != votingTokenAddress_, 
      "N0N3DAO: new token address is the same with old token address");
    address oldVotingToken = votingTokenAddress;
    votingTokenAddress = votingTokenAddress_;
    emit VOTINGTOKENCHANGE(oldVotingToken, votingTokenAddress);
  }

  function proposalLockUntil(uint256 proposalId) public view proposalExisted(proposalId) returns (uint256){
    return proposals[proposalId].startLockAt + proposals[proposalId].noOfBlockWithinActivePeriod;
  }

  function setFeePerBlock(uint feePerBlock_) external onlyDAO {
    require(feePerBlock_ > 0, "N0N3DAO: should greater than 0");
    uint256 oldFee = feePerBlockWithinActivePeriod;
    feePerBlockWithinActivePeriod = feePerBlock_;
    emit FEEPERBLOCKCHANGED(block.number, oldFee, feePerBlockWithinActivePeriod);
  }

  /**
  * Proposal owner queue(proposalAddress, proposalFee) returns proposalId
  * {ONLY} Proposal owner discard(proposalId) return success/failed
  * {SHOULD} Proposal owner pushIntoVoting(proposalId) returns success/failed
  * {SHOULD} Proposal owner ratify(proposalId) returns ProposalState
   */

  function queue(address proposalAddress_, uint proposalFee_) noRaceLocked external returns(uint){
    require(proposalFee_ > minProposalFee, "N0N3DAO: not enough fee");
    uint256 feeTaken = 0;
    if(proposalFee_ > maxNoOfBlockWithinActivePeriod.mul(feePerBlockWithinActivePeriod)){
      feeTaken = proposalFee_.sub(maxNoOfBlockWithinActivePeriod.mul(feePerBlockWithinActivePeriod));
    }else{
      feeTaken = proposalFee_;
    }
    IERC20(votingTokenAddress).transfer(address(this), feeTaken);
    uint256 noOfBlockWithinActivePeriod = feeTaken.div(feePerBlockWithinActivePeriod);
    uint256 proposalId = totalProposal + 1;
    proposals[proposalId] = ProposalInfo({
      addr: proposalAddress_,
      power: 0,
      startLockAt: 0,
      noOfBlockWithinActivePeriod: noOfBlockWithinActivePeriod,
      waitingForRatifyNoOfBlock: waitingForRatifyNoOfBlock,
      state: ProposalState.WAITING,
      owner: msg.sender,
      noOfSupporter: 0,
      paid: feeTaken,
      currency: votingTokenAddress,

      prev: 0,
      next: 0
    });
    newestProposalId = proposalId;
    emit QUEUED(proposalAddress_, msg.sender, proposalId);
    return newestProposalId;
  }

  /*
  ** Get a 80% refund for discard
  ** TODO: should be a parameter
  ** TODO: should remove from mapping // maybe array with push&pop is a better choice
   */
  function discard(uint256 proposalId_) proposalExisted(proposalId_) noRaceLocked external returns (bool){
    require(proposals[proposalId_].owner == msg.sender 
      && proposals[proposalId_].state == ProposalState.WAITING, 
      "N0N3DAO: cannot discard, you are not the owner");
    require(proposals[proposalId_].state == ProposalState.DISCARDED, "N0N3DAO: already discarded");
    lockRace();
    proposals[proposalId_].state = ProposalState.DISCARDED;
    unlockRace();
    emit DISCARDED(proposals[proposalId_].addr, msg.sender, proposalId_);
    address votingTokenAddressAtQueue = proposals[proposalId_].currency;
    uint256 refund = proposals[proposalId_].paid.mul(4).div(5);
    proposals[proposalId_].paid -= refund;
    IERC20(votingTokenAddressAtQueue).transferFrom(address(this), msg.sender, refund);
    return true;
  }

  /**
  * pushIntoVoting if the proposals[currentProposalId] is expired
  */
  function pushIntoVoting(uint256 proposalId_) external proposalExisted(proposalId_){
    // is valid proposal? WAITING
    ProposalInfo storage nextProposal = proposals[proposalId_];
    ProposalInfo storage lastProposal = proposals[currentProposalId];
    require(nextProposal.state == ProposalState.WAITING, "N0N3DAO: invalid state");
    require(proposalLockUntil(currentProposalId) < block.number, "N0N3DAO: current proposal still in effect");
    // is the latest proposal executed?
    if(lastProposal.state == ProposalState.PASSED)
    {}
    
  }

  function yes() external {
    _beforeVote();
    uint256 votingPower = IERC20(votingTokenAddress).balanceOf(msg.sender);
    require(votingPower > 0, "N0N3DAO: You must have some token to vote");
    proposalSupporters[currentProposalId][msg.sender] = votingPower;
    proposals[currentProposalId].power += votingPower;
    _afterVote(msg.sender, true, votingPower);
  }
  
  function no() external {
    _beforeVote();
    require(proposalSupporters[currentProposalId][msg.sender] > 0, "N0N3DAO: You didn't cast a vote");
    uint256 votingPower = IERC20(votingTokenAddress).balanceOf(msg.sender);
    delete proposalSupporters[currentProposalId][msg.sender];
    proposals[currentProposalId].power -= votingPower;
    _afterVote(msg.sender, false, votingPower);
  }

  function _beforeVote() view private {
    require(currentProposalId > 0, "N0N3DAO: There is no proposal to vote");
    require(proposals[currentProposalId].addr != address(0), "N0N3DAO: current proposal is not set");
    require(proposalLockUntil(currentProposalId) > block.number, "N0N3DAO: current proposal is expired");
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
    Proposal(proposals[currentProposalId].addr).execute();
  }

  function calculateProposalFee(uint howManyDays) external view returns (uint) {
    return feePerBlockWithinActivePeriod * howManyDays * 28800;
  }


}