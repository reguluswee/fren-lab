// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

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
    function mintOption(address giveAddress, uint256 eeaRate, uint256 amp, uint256 cRank, uint256 term, uint256 maturityTs, address[] calldata pMinters) external;
    function burnOption(uint256 tokenId) external;
    function ownerOfWithPack(uint256 tokenId) external view returns (bool, BullPack memory);
    function balanceOf(address owner) external view returns (uint256 balance);
}


contract BatchMint is Ownable {
    using ABDKMath64x64 for uint256;
    // IFrenReward private _REWARD = IFrenReward(0x7127deeff734cE589beaD9C4edEFFc39C9128771);
    IFrenReward private _REWARD;

    function getFren() external view returns (address) {
        return address(_REWARD);
    }

    struct MintParams {
        IFrenNFT frenNFT;
        IOptionNFT optionNFT;
    }

    MintParams private _runParam;

    uint256 private _honor = 100;

    event RewardResponse(bool success, bytes data);

    constructor(address _fren) {
        _REWARD = IFrenReward(_fren);
    }

    function relayBatchParams(address _frenNFT, address _optionNFT) external onlyOwner {
        if(_frenNFT != address(0)) {
            _runParam.frenNFT = IFrenNFT(_frenNFT);
        }
        if(_optionNFT != address(0)) {
            _runParam.optionNFT = IOptionNFT(_optionNFT);   
        }
    }

    function getBatchParams() external view returns(MintParams memory) {
        return _runParam;
    }

    function claimRank(uint256 times, uint256 term) external payable {
        require(address(_runParam.optionNFT) != address(0), "batch minter not ready, please wait.");
        address user = tx.origin;
        
        require(_runParam.optionNFT.balanceOf(user) == 0, "minting now, need to claim or transfer option.");

        require(msg.value == times * 1 ether, 'batch mint value not correct.');

        uint256 singlePay = msg.value / times;
        MintInfo memory m;
        address[] memory proxyMinters = new address[](times);
        for(uint256 i; i<times; i++){
            Minter get = new Minter(address(_REWARD));
            // get.claimRank{value : singlePay}(term);
            (bool exeResult, ) = address(get).call{value:singlePay}(abi.encodeWithSignature("claimRank(uint256)", term));
            
            if(!exeResult) {
                // stop and revert all transaction
                revert(string(abi.encodePacked("FREN token claim Error.", Strings.toString(i))));
            }
            proxyMinters[i] = address(get);
            if(i == times - 1) {    // get the last one minting information.
                m = get.getUserMint();
            }
        }
        if(proxyMinters.length > 0) {
            _runParam.optionNFT.mintOption(user, m.eaaRate, m.amplifier, m.rank, m.term, m.maturityTs, proxyMinters);
        }

        // mint Identity NFT
        if(address(_runParam.frenNFT) != address(0)&& times >= _honor) {
            _runParam.frenNFT.bMint(user, times);
        }
    }

    function claimMintReward(uint256 tokenId) external {
        require(address(_runParam.optionNFT) != address(0), "batch minter not ready, please wait.");
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
            (bool ok, bytes memory data) = address(get).call(abi.encodeWithSignature("claimMintReward()"));
            if(!ok) {
                //revert(string(abi.encodePacked("FREN token claim Error.", data)));
                emit RewardResponse(ok, data);
            }
            uint256 balance = _REWARD.balanceOf(get);
            _REWARD.transferFrom(get, user, balance);
        }
        optionNFT.burnOption(tokenId);
    }
}