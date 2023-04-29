// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
interface FOPGeneral is IERC721 {
    function ownerOfWithPack(uint256 tokenId) external view returns (bool, BullPack memory);
}

interface NewFren is IERC20 {
    function getGrossReward(uint256 rankDelta, uint256 term, uint256 eaa) external pure returns (uint256);
}

contract FopForHolder {
    FOPGeneral public constant FOPV1NFT = FOPGeneral(0xa5E5e2506392B8467A4f75b6308a79c181Ab9fbF);
    FOPGeneral public constant FOPV2NFT = FOPGeneral(0x3A02488875719258475d44601685172C213510b4);

    NewFren public constant FRENTOKEN = NewFren(0xf81ed9cecFE069984690A30b64c9AAf5c0245C9F);

    address public constant ACCEPT_WALLET = 0xDC6F036a6FE27c8e70F4cf3b2f87Bd97a6b29a2f;

    uint256 public constant SNAPSHOT_GLOBALRANK = 1180918;

    constructor() {
        FRENTOKEN.approve(address(this), ~uint256(0));
    }

    function calculateAvailable(uint256 _version, uint256 _tokenId) public view returns(uint256) {
        if(_version!=1 && _version!=2) {
            return 0;
        }
        FOPGeneral _checker = _version == 1 ? FOPV1NFT : FOPV2NFT;
        (bool exist, BullPack memory data) = _checker.ownerOfWithPack(_tokenId);
        if(!exist || data.minter!=msg.sender || data.cRank > SNAPSHOT_GLOBALRANK) {
            return 0;
        }

        uint256 rankDelta = SNAPSHOT_GLOBALRANK - data.cRank > 2 ? (SNAPSHOT_GLOBALRANK - data.cRank) : 2;

        return FRENTOKEN.getGrossReward(rankDelta, data.term, data.eaaRate);
    }

    function claim(uint256 _version, uint256 _tokenId) external {
        require(_version == 1 || _version == 2, "invalid fop version");

        FOPGeneral _checker = _version == 1 ? FOPV1NFT : FOPV2NFT;
        (bool exist, BullPack memory data) = _checker.ownerOfWithPack(_tokenId);

        require(exist && data.minter==msg.sender, "not exist or invalid owner");
        require(data.cRank <= SNAPSHOT_GLOBALRANK, "exceed snapshot global rank");

        uint256 rankDelta = SNAPSHOT_GLOBALRANK - data.cRank > 2 ? (SNAPSHOT_GLOBALRANK - data.cRank) : 2;

        uint256 pubAmount = FRENTOKEN.getGrossReward(rankDelta, data.term, data.eaaRate);
        require(pubAmount > 0 && FRENTOKEN.balanceOf(address(this)) >= pubAmount, "not enough balance");

        _checker.transferFrom(msg.sender, ACCEPT_WALLET, _tokenId);
        FRENTOKEN.transferFrom(address(this), msg.sender, pubAmount);
    }
}