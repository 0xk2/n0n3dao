//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FUN is ERC20Pausable, Ownable {
  constructor() ERC20("N0n3 FUN","FUN"){
  }

  function mint(uint256 amount_, address recipient_) external onlyOwner {
    require(recipient_ != address(0), "FUN: cannot mint token for address(0)");
    _mint(address(recipient_), amount_);
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }
}