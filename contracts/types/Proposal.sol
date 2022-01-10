//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./N0N3AccessControl.sol";
import "../interfaces/iN0N3DAO.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
abstract contract Proposal is N0N3AccessControl, Ownable {
  // proposalFee in DAO's token
  uint public proposalFee;

  constructor(uint proposalFee_){
    proposalFee = proposalFee_;
  }

  function propose() onlyOwner() external {
    iN0N3DAO(DAOAddress).pushProposal(address(this), proposalFee);
  }

  function _execute() virtual internal;

  function changeProposalFee(uint newFee) public {
    proposalFee = newFee;
  }

  /*
  * onlyDAO can execute a proposal
  */
  function execute() onlyDAO() external {
    _execute();
  }
}