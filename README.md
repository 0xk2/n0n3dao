# Motivation

This project propose a simple process for execute onchain proposal

## The process for voting is done as following:
 (1) `Owner` `queue(address proposalAddress, uint256 fee) a proposal`. `Owner` can `discard()` while queuing
 
 (2) `Owner` `pushIntoVoting(uint256 proposalId)` => Proposal is under community voting the call is valid if block.number > {`currentProposal.lockUntil` + `waitingForBallotAndEnforce`} hence set new currentProposal
 
 (3) `CommunityMember` say `yes()` (then change their mind to `no()`) required `block.number` < `currentProposal.lockUntil`
 
 (4) `Owner` `ratify()` to evaluate `currentProposal.state` to `ballotCall()` and trigger `iProposal.execute()`