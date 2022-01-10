//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface iN0N3DAO {
  function pushProposal(address proposalAddress, uint proposalFee) external returns(uint lastBlock);
}