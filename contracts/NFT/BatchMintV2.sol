// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./BatchLib.sol";

interface IOptionNFTV2 {
    function mintOption(address giveAddress, uint256 eeaRate, uint256 amp, uint256 cRank, uint256 term, uint256 maturityTs, uint256 canTransfer,
        address[] calldata pMinters) external returns(uint256 tokenId);
    function burnOption(uint256 tokenId) external;
    function ownerOfWithPack(uint256 tokenId) external view returns (bool, BullPack memory);
    function balanceOf(address owner) external view returns (uint256 balance);
}

contract BatchMintV2 is Ownable {
    using ABDKMath64x64 for uint256;
    IFrenReward private _REWARD;

    function getFren() external view returns (address) {
        return address(_REWARD);
    }

    struct MintParams {
        IOptionNFTV2 optionNFT;
        uint256 recommendFee; // of 100
        uint256 inviteCanTransfer;
        uint256 batchCan;
    }

    MintParams private _runParam;

    uint256 constant public MAX_BATCH_HONOR = 50;

    //rec invite relation, could be deleted
    // mapping(address => address) public recMapping;
    mapping(uint256 => address) public recMapping;  // tokenId => inviter

    //rec all invite count number
    mapping(address => uint256) public totalLeaderboard;
    address[] public allInviters;

    event RewardResponse(bool success, bytes data);
    event RecommendRecord(address user, uint256 tokenId);

    constructor(address _fren) {
        require(_fren != address(0), "invalid token address.");
        _REWARD = IFrenReward(_fren);
        _runParam.inviteCanTransfer = 0;  //default dont offer nft for the invited user
        _runParam.batchCan = 1; //default open batch status
    }

    function relayBatchParams(address _optionNFT, uint256 _newFee, uint256 _inviteCanTransfer, uint256 _batchCan) external onlyOwner {
        require(_newFee<=100 && _newFee>=0, "invalid fee parameter");
        require(_inviteCanTransfer==0 || _inviteCanTransfer==1, "invalid invite parameter");
        require(_batchCan==0 || _batchCan==1, "invalid batch parameter");

        if(_optionNFT != address(0)) {
            _runParam.optionNFT = IOptionNFTV2(_optionNFT);   
        }
        _runParam.recommendFee = _newFee;
        _runParam.inviteCanTransfer = _inviteCanTransfer;
        _runParam.batchCan = _batchCan;
    }

    function getBatchParams() external view returns(MintParams memory) {
        return _runParam;
    }

    function claimRank(address _recer, uint256 times, uint256 term) external payable {
        require(address(_runParam.optionNFT) != address(0), "batch minter not ready, please wait.");
        require(times > 0 && times <=MAX_BATCH_HONOR, "invalid batch times");
        require(_runParam.batchCan == 1, "batch tool temporarily paused.");
        address user = tx.origin;
        
        require(_runParam.optionNFT.balanceOf(user) == 0, "minting now, need to claim or transfer option.");

        require(msg.value == times * 1 ether, 'batch mint value not correct.');

        uint256 singlePay = msg.value / times;
        MintInfo memory m;
        address[] memory proxyMinters = new address[](times);
        for(uint256 i; i<times; i++){
            Minter get = new Minter(address(_REWARD));
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
            uint256 canTransfer = _recer!= address(0) ? _runParam.inviteCanTransfer : 1;
            uint256 fopV2TokenId = _runParam.optionNFT.mintOption(user, m.eaaRate, m.amplifier, m.rank, m.term, m.maturityTs, canTransfer,
                proxyMinters);
            if(_recer != address(0)) {
                recMapping[fopV2TokenId] = _recer;
                emit RecommendRecord(_recer, fopV2TokenId);
                _recordInvite(_recer);
            }
        }
    }

    function claimMintReward(uint256 tokenId) external {
        require(address(_runParam.optionNFT) != address(0), "batch minter not ready, please wait.");
        require(tokenId > 0, "invalid token id.");
        address user = tx.origin;
        IOptionNFTV2 optionNFT = _runParam.optionNFT;
        require(optionNFT.balanceOf(user) > 0, "have not minting infos.");

        (bool success, BullPack memory _bp) = optionNFT.ownerOfWithPack(tokenId);
        require(success, "option minting not sure.");
        //check owner
        require(_bp.minter == user, "mint error: not owner.");
        address[] memory getter = _bp.pMinters;
        require(getter.length > 0, "minter bot not found.");

        address recommendAddress = recMapping[tokenId]; //try to find out
        for(uint256 i; i<getter.length; i++) {
            address get = getter[i];
            (bool ok, bytes memory data) = address(get).call(abi.encodeWithSignature("claimMintReward()"));
            if(!ok) {
                emit RewardResponse(ok, data);  //try claiming reward out
            }
            uint256 balance = _REWARD.balanceOf(get);

            if(balance > 0) {
                if(recommendAddress != address(0)) {
                    delete recMapping[tokenId]; //non reentry
                    uint256 recFee = balance / 100 * _runParam.recommendFee;
                    balance = balance - recFee;
                    if(recFee > 0) {
                        _REWARD.transferFrom(get, recommendAddress, recFee);
                    }
                }
                if(balance > 0) {
                    _REWARD.transferFrom(get, user, balance);
                }
                
            }
        }
        optionNFT.burnOption(tokenId);
    }

    function totalInviters() public view returns(uint256) {
        return allInviters.length;
    }

    function _recordInvite(address _from) internal {
        if(_from==address(0)) {
            return;
        }
        uint256 count = totalLeaderboard[_from];
        if(count++==0) {
            //first time need pushing
            allInviters.push(_from);
        }
        totalLeaderboard[_from] = count;
    }
}