// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IBurnableFOP {

    struct BullPack {
        address minter;
        uint256 tokenId;
        uint256 eaaRate;
        uint256 amp;
        uint256 cRank;
        uint256 term;
        uint256 maturityTs;
        address[] pMinters;
    }
    
    event OpBurn(address indexed minter, uint256 tokenId);

    event OpMint(address indexed minter, uint256 tokenId, uint256 index);

    function burnOption(uint256 tokenId) external;

    function mintOption(address giveAddress, uint256 eeaRate, uint256 amp, uint256 cRank, uint256 term, address[] calldata pMinters) external;

    function ownerOfWithPack(uint256 tokenId) external view returns (bool, BullPack memory);

}