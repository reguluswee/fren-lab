// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

struct BullPackV1 {
    address minter;
    uint256 tokenId;
    uint256 eaaRate;
    uint256 amp;
    uint256 cRank;
    uint256 term;
    uint256 maturityTs;
    address[] pMinters;
}

struct BullPackV2 {
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

interface FOPV1 is IERC721 {
    function ownerOfWithPack(uint256 tokenId) external view returns (bool, BullPackV1 memory);
}

interface FOPV2 is IERC721 {
    function ownerOfWithPack(uint256 tokenId) external view returns (bool, BullPackV2 memory);
}

interface NewFren is IERC20 {
    function getGrossReward(uint256 rankDelta, uint256 term, uint256 eaa) external pure returns (uint256);
}

contract FopForHolder is Ownable {
    FOPV1 public constant FOPV1NFT = FOPV1(0xa5E5e2506392B8467A4f75b6308a79c181Ab9fbF);
    FOPV2 public constant FOPV2NFT = FOPV2(0x3A02488875719258475d44601685172C213510b4);

    NewFren public constant FRENTOKEN = NewFren(0xf81ed9cecFE069984690A30b64c9AAf5c0245C9F);

    address public constant ACCEPT_WALLET = 0xDC6F036a6FE27c8e70F4cf3b2f87Bd97a6b29a2f;

    uint256 public constant SNAPSHOT_GLOBALRANK = 1180918;

    constructor() {
        FRENTOKEN.approve(address(this), ~uint256(0));
    }

    function drawback() external onlyOwner {
        FRENTOKEN.transferFrom(address(this), msg.sender, FRENTOKEN.balanceOf(address(this)));
    }

    function calculateAvailable(uint256 _version, uint256 _tokenId) public view returns(uint256) {
        if(_version==1) {
            (bool exist, BullPackV1 memory data) = FOPV1NFT.ownerOfWithPack(_tokenId);
            if(!exist || data.minter!=msg.sender || data.cRank > SNAPSHOT_GLOBALRANK) {
                return 0;
            }
            uint256 rankDelta = SNAPSHOT_GLOBALRANK - data.cRank > 2 ? (SNAPSHOT_GLOBALRANK - data.cRank) : 2;
            return FRENTOKEN.getGrossReward(rankDelta, data.term, (1000 + data.eaaRate));
        } else if(_version==2) {
            (bool exist, BullPackV2 memory data) = FOPV2NFT.ownerOfWithPack(_tokenId);
            if(!exist || data.minter!=msg.sender || data.cRank > SNAPSHOT_GLOBALRANK) {
                return 0;
            }
            uint256 rankDelta = SNAPSHOT_GLOBALRANK - data.cRank > 2 ? (SNAPSHOT_GLOBALRANK - data.cRank) : 2;
            return FRENTOKEN.getGrossReward(rankDelta, data.term, (1000 + data.eaaRate));
        } else {
            return 0;
        }
    }

    function claimV1(uint256 _tokenId) external {
        (bool exist, BullPackV1 memory data) = FOPV1NFT.ownerOfWithPack(_tokenId);

        require(exist && data.minter==msg.sender, "not exist or invalid owner");
        require(data.cRank <= SNAPSHOT_GLOBALRANK, "exceed snapshot global rank");
        require(block.timestamp >= data.maturityTs, "invalid maturityTs");

        uint256 rankDelta = SNAPSHOT_GLOBALRANK - data.cRank > 2 ? (SNAPSHOT_GLOBALRANK - data.cRank) : 2;

        uint256 pubAmount = FRENTOKEN.getGrossReward(rankDelta, data.term, (1000 + data.eaaRate));
        require(pubAmount > 0 && FRENTOKEN.balanceOf(address(this)) >= pubAmount, "not enough balance");

        FOPV1NFT.transferFrom(msg.sender, ACCEPT_WALLET, _tokenId);
        FRENTOKEN.transferFrom(address(this), msg.sender, pubAmount);
    }

    function claimV2(uint256 _tokenId) external {
        (bool exist, BullPackV2 memory data) = FOPV2NFT.ownerOfWithPack(_tokenId);

        require(exist && data.minter==msg.sender, "not exist or invalid owner");
        require(data.cRank <= SNAPSHOT_GLOBALRANK, "exceed snapshot global rank");
        require(block.timestamp >= data.maturityTs, "invalid maturityTs");

        uint256 rankDelta = SNAPSHOT_GLOBALRANK - data.cRank > 2 ? (SNAPSHOT_GLOBALRANK - data.cRank) : 2;

        uint256 pubAmount = FRENTOKEN.getGrossReward(rankDelta, data.term, (1000 + data.eaaRate));
        require(pubAmount > 0 && FRENTOKEN.balanceOf(address(this)) >= pubAmount, "not enough balance");

        FOPV1NFT.transferFrom(msg.sender, ACCEPT_WALLET, _tokenId);
        FRENTOKEN.transferFrom(address(this), msg.sender, pubAmount);
    }

}