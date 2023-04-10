// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "../Math.sol";

interface INewFren {
    function genesisTs() external view returns(uint256);
    function totalSupply() external view returns (uint256);
    function totalFrenStakedAmount() external view returns(uint256);

    function launchTs() external view returns(uint256);
}

contract FrenCooker {
    using Math for uint256;
    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;
    
    uint256 public constant SECONDS_IN_DAY = 3_600 * 24;
    uint256 public constant DAYS_IN_YEAR = 365;

    uint256 public constant START_PRICE = 1 ether;
    uint256 public constant SECONDS_IN_HOUR = 60 * 60;
    uint256 public constant HOURS_IN_YEAR = 365 * 24;
    uint256 public constant SECONDS_IN_YEAR = HOURS_IN_YEAR * SECONDS_IN_HOUR;

    uint256 public constant FREN_APY_START = 20;
    uint256 public constant FREN_APY_DAYS_STEP = 90;
    uint256 public constant FREN_APY_END = 2;

    INewFren public frenToken;

    constructor(address _token) {
        require(_token != address(0));
        frenToken = INewFren(_token);
    }

    function calculateAPY() public view returns (uint256) {
        // INewFren frenToken = INewFren(_fren);
        // uint256 decrease = (block.timestamp - frenToken.genesisTs()) / (SECONDS_IN_DAY * FREN_APY_DAYS_STEP);
        // if (FREN_APY_START - FREN_APY_END < decrease) return FREN_APY_END;
        // return FREN_APY_START - decrease;

        if(frenToken.totalSupply()==0) {
            return FREN_APY_START;
        }

        uint256 stakeRatio = frenToken.totalFrenStakedAmount() * 10 / frenToken.totalSupply();

        uint256 decrease = (block.timestamp - frenToken.genesisTs()) / (SECONDS_IN_DAY * FREN_APY_DAYS_STEP);
        
        if (FREN_APY_START - FREN_APY_END < decrease + stakeRatio) {
            stakeRatio = (stakeRatio == 0 ? 1 : stakeRatio);
            return FREN_APY_END + 10 / stakeRatio;
        }
        return FREN_APY_START - decrease - stakeRatio;
    }

    function luckyPrice(uint256 _ts) public view returns(uint256) {
        // if(block.timestamp <= launchTs) return START_PRICE;

        uint256 secTime = _ts - frenToken.launchTs();
        uint256 hourPassed = ABDKMath64x64.divu(secTime, SECONDS_IN_HOUR).toUInt();
        if(hourPassed == 0) {
            return START_PRICE;
        }

        if(secTime >= 4 * SECONDS_IN_YEAR) {
            return 16 ether;
        }

        uint256 expN = ABDKMath64x64.divu(secTime, SECONDS_IN_YEAR).toUInt();    /* launch year towards zero */
        uint256 baseCost = ABDKMath64x64.exp_2(ABDKMath64x64.fromUInt(expN)).toUInt() * START_PRICE;

        uint256 dyCost = ABDKMath64x64.mulu(
            ABDKMath64x64.divu(baseCost, HOURS_IN_YEAR),
            (hourPassed - (expN) * 365 * 24)
        );

        return Math.max(
            (baseCost + dyCost),
            START_PRICE    
        );
    }
}
