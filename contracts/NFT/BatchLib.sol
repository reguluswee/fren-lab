// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

struct MintInfo {
    address user;
    uint256 term;
    uint256 maturityTs;
    uint256 rank;
    uint256 amplifier;
    uint256 eaaRate;
}
struct BullPack {
    address minter;
    uint256 tokenId;
    uint256 eaaRate;
    uint256 amp;
    uint256 cRank;
    uint256 term;
    uint256 maturityTs;
    uint256 canTransfer;
    address[] pMinters;
}

interface IFrenMint{
    function claimRank(uint256 term) external payable;
    function claimMintReward() external;
    function approve(address spender, uint256 amount) external returns (bool);

    function getUserMint() external view returns (MintInfo memory);
}

interface IFrenReward{
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Minter{
    // IFrenMint private _FREN = IFrenMint(0x7127deeff734cE589beaD9C4edEFFc39C9128771);
    IFrenMint private _FREN;

    constructor(address _fren) {
        _FREN = IFrenMint(_fren);
        _FREN.approve(msg.sender, ~uint256(0));
    }
    
    function claimRank(uint256 term) public payable {
        _FREN.claimRank{value: msg.value}(term);
    }

    function getUserMint() external view returns (MintInfo memory) {
        return _FREN.getUserMint();
    }

    function claimMintReward() public {
        _FREN.claimMintReward();
        selfdestruct(payable(tx.origin));
    }

}

interface IFrenNFT {
    function bMint(address giveAddress, uint256 burnCount) external returns (bool);
    function balanceOf(address owner) external view returns (uint256);
}