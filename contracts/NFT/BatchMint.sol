// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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

interface IOptionNFT {
    function mintOption(address giveAddress, uint256 eeaRate, uint256 amp, uint256 cRank, uint256 term, address[] calldata pMinters) external;
    function burnOption(uint256 tokenId) external;
    function ownerOfWithPack(uint256 tokenId) external view returns (bool, BullPack memory);
    function balanceOf(address owner) external view returns (uint256 balance);
}


contract BatchMint is Ownable {
    using ABDKMath64x64 for uint256;

    // mapping (address=>mapping (uint256=>address[])) public userContracts;
    // IFrenReward private _REWARD = IFrenReward(0x7127deeff734cE589beaD9C4edEFFc39C9128771);
    IFrenReward private _REWARD;

    struct MintParams {
        address frenNFT;
        address optionNFT;
    }

    MintParams private _runParam = MintParams({
        frenNFT : address(0),
        optionNFT : address(0)
    });

    uint256[] private _honor = [100];   // 2 for test

    event RewardResponse(bool success, bytes data);

    constructor(address _fren) {
        _REWARD = IFrenReward(_fren);
    }

    function relayBatchParams(address _frenNFT, address _optionNFT) external onlyOwner {
        _runParam.frenNFT = _frenNFT;
        _runParam.optionNFT = _optionNFT;
    }

    function getBatchParams() external view returns(MintParams memory) {
        return _runParam;
    }

    function claimRank(uint256 times, uint256 term) external payable {
        require(_runParam.optionNFT != address(0), "batch minter not ready, please wait.");
        address user = tx.origin;
        IOptionNFT optionNFT = IOptionNFT(_runParam.optionNFT);
        
        require(optionNFT.balanceOf(user) == 0, "minting now, need to claim or transfer option.");

        uint256 multiple = 0;
        for(uint256 i=0; i<_honor.length; i++) {
            if(_honor[i] == times) {
                multiple = _honor[i];
                break;
            }
        }

        require(msg.value == times * 1 ether, 'batch mint value not correct.');

        uint256 singlePay = msg.value / times;
        MintInfo memory m;
        address[] memory proxyMinters = new address[](times);
        for(uint256 i; i<times; i++){
            Minter get = new Minter(address(_REWARD));
            get.claimRank{value : singlePay}(term);
            
            proxyMinters[i] = address(get);
            if(i == times - 1) {
                m = get.getUserMint();
            }
            // userContracts[user][term].push(address(get));
        }
        optionNFT.mintOption(user, m.eaaRate, m.amplifier, m.rank, m.term, proxyMinters);
        

        // mint Identity NFT
        if(_runParam.frenNFT != address(0) && multiple > 0) {
            //hund-coint NFT
            IFrenNFT(_runParam.frenNFT).bMint(user, multiple);
        }
    }

    function claimMintReward(uint256 tokenId) external {
        require(_runParam.optionNFT != address(0), "batch minter not ready, please wait.");
        address user = tx.origin;
        IOptionNFT optionNFT = IOptionNFT(_runParam.optionNFT);
        require(optionNFT.balanceOf(user) > 0, "have not minting infos.");

        (bool success, BullPack memory _bp) = optionNFT.ownerOfWithPack(tokenId);
        require(success, "option minting not sure.");
        
        //check owner
        require(_bp.minter == user, "mint error: not owner.");
        address[] memory getter = _bp.pMinters;
        require(getter.length > 0, "minter bot not found.");
        
        for(uint256 i; i<getter.length; i++) {
            address get = getter[i];
            
            (bool ok, bytes memory data) = address(get).call("0x52c7f8dc");
            if(!ok) {
                // just record for fail transaction.
                emit RewardResponse(ok, data);
            }
            // address owner = tx.origin;
            uint256 balance = _REWARD.balanceOf(get);
            _REWARD.transferFrom(get, user, balance);
        }
        optionNFT.burnOption(tokenId);
    }
}