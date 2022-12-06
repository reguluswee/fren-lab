// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IBurnableFOPV2 {

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
    
    event OpBurn(address indexed minter, uint256 tokenId);

    event OpMint(address indexed minter, uint256 tokenId, uint256 index);

    function burnOption(uint256 tokenId) external;

    function mintOption(address giveAddress, uint256 eeaRate, uint256 amp, uint256 cRank, uint256 term, uint256 maturityTs, uint256 canTransfer,
        address[] calldata pMinters) external returns(uint256 tokenId);

    function ownerOfWithPack(uint256 tokenId) external view returns (bool, BullPack memory);

}