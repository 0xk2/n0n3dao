const { expect } = require("chai");
const { ethers, waffle } = require("hardhat");
const { BigNumber } = require("ethers");
const {deployContract} = waffle;
const FUNArtifact = require("../artifacts/contracts/FUN.sol/FUN.json");

const address0 = "0x0000000000000000000000000000000000000000";

function _getToken(token){
  return ethers.utils.parseUnits(token.toString(), 18);
}

describe("FUN", function () {
  let deployer, dao, addr1, addr2, addrs;
  let FUN;
  beforeEach(async function() {
    [deployer, dao, addr1, addr2, ...addrs] = await ethers.getSigners();
    FUN = await deployContract(deployer, FUNArtifact);
  });
  
  it("should allow only owner can mint token", async function(){
    await expect(FUN.connect(deployer).mint(_getToken(100),deployer.address)).to.emit(FUN, "Transfer");
    let balance = await FUN.connect(deployer).balanceOf(deployer.address);
    expect(balance).equal(_getToken(100).toString());
    await expect(FUN.connect(deployer).mint(_getToken(50),addr1.address)).to.emit(FUN, "Transfer")
      .withArgs(address0, addr1.address, _getToken(50));
    balance = await FUN.connect(addr1).balanceOf(addr1.address);
    expect(balance).equal(_getToken(50).toString());
    await expect(FUN.connect(addr1).mint(_getToken(100),0)).to.be.reverted;
  });

  it("should allow transfer ownership", async function(){
    await expect(FUN.connect(dao).mint(_getToken(100),dao.address)).to.be.reverted;
    await expect(FUN.connect(deployer).transferOwnership(dao.address)).to
      .emit(FUN, "OwnershipTransferred").withArgs(deployer.address, dao.address);
    await expect(FUN.connect(dao).mint(_getToken(100),dao.address)).to.emit(FUN, "Transfer")
      .withArgs(address0, dao.address, _getToken(100));
    let balance = await FUN.connect(dao).balanceOf(dao.address);
    expect(balance).equal(_getToken(100).toString());
  });
  
  it("should allow owner to pause", async function(){
    await expect(FUN.connect(deployer).mint(_getToken(50),addr1.address)).to.emit(FUN, "Transfer")
      .withArgs(address0, addr1.address, _getToken(50));
    await expect(FUN.connect(deployer).pause()).to.emit(FUN, "Paused").withArgs(deployer.address);
    await expect(FUN.connect(addr1).transfer(addr2.address, _getToken(30))).to.be.reverted;
    await expect(FUN.connect(deployer).unpause()).to.emit(FUN, "Unpaused").withArgs(deployer.address);
    await expect(FUN.connect(addr1).transfer(addr2.address, _getToken(30))).to.emit(FUN, "Transfer");
    let balance = await FUN.connect(addr2).balanceOf(addr2.address);
    expect(balance).equal(_getToken(30).toString());
  })
});