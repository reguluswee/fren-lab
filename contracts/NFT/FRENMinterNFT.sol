// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../Math.sol";
import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./IMinter.sol";

contract FRENMinterNFT is Context, IMinter, Ownable, ReentrancyGuard, ERC721A {
    address private _minter;

    uint256 private _biggerMinum = 100;

    constructor() ERC721A("FRENClubs", "FRENBIG") {
    }

    function transferMinter(address newMinter) external override onlyOwner {
        require(newMinter != address(0), "Mintable: new minter is the zero address");
        address oldMinter = _minter;
        _minter = newMinter;
        emit MintershipTransferred(oldMinter, newMinter);
    }

    modifier onlyMinter() {
        _checkMinter();
        _;
    }

    function _checkMinter() internal view virtual {
        require(minter() == _msgSender(), "Mintable: caller is not the allowed minter");
    }

    function minter() public view virtual returns (address) {
        return _minter;
    }

    function bMint(address giveAddress, uint256 burnCount) external onlyMinter returns (bool) {
        require(burnCount > 0, "ERROR: need to be large than zero.");
        require(burnCount%_biggerMinum == 0, "ERROR: need to be multiple of minum.");

        uint256 hadMintedAmount = balanceOf(giveAddress);
        if(hadMintedAmount > 0) {
            return false;
        }
        _mint(giveAddress, 1);
        uint256 currentIndex = totalSupply();

        emit MintEvp(giveAddress, burnCount, currentIndex);
        return true;
    }
}
