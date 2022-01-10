//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract N0N3AccessControl {
  address public immutable DAOAddress;
  constructor(address DAOAddress_) {
    DAOAddress = DAOAddress_;
  }
  modifier onlyDAO() {
    require(msg.sender == DAOAddress);
    _;
  }
}