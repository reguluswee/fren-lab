// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "../Math.sol";

interface MdaoBathProxy {
    function userContracts(address user, uint256 term, uint256 index) external view returns(address proxyAddr);

    function userTermLength(address user, uint256 term) external view returns(uint256 length);
}

struct FrenMintInfo {
    address user;
    uint256 term;
    uint256 maturityTs;
    uint256 rank;
    uint256 amplifier;
    uint256 eaaRate;
}

interface FrenMint {
    // mapping(address => MintInfo) public userMints;
    function userMints(address user) external view returns(FrenMintInfo memory);
    function globalRank() external view returns(uint256);

    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract CompensateMdao is Ownable {
    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;

    MdaoBathProxy public constant MDAOPROXY = MdaoBathProxy(0xcDfd138a8E59916E687F869f5c9D6B6f4334aE73);

    FrenMint public constant FRENPROXY = FrenMint(0x7127deeff734cE589beaD9C4edEFFc39C9128771);

    uint256 public constant SECONDS_IN_DAY = 3_600 * 24;
    uint256 public constant PENALTY_DAY = 7 * SECONDS_IN_DAY;
    uint256 public constant WITHDRAWAL_WINDOW_DAYS = 7;
    uint256 public constant MAX_PENALTY_PCT = 99;
    uint256 public constant CUTOFFTS = 1672502399;  // 20221231 23:59:59

    uint256 public stage = 0;
    uint256 public startBlock;

    mapping(address => mapping(uint256 => uint256)) public ethCostData;
    mapping(address => mapping(uint256 => uint256)) public frenLossData;
    mapping(address => mapping(uint256 => uint256)) public recordData;

    constructor() {
        startBlock = block.number;
        FRENPROXY.approve(address(this), ~uint256(0));
    }

    function _penalty(uint256 secsLate) internal pure returns (uint256) {
        uint256 daysLate = secsLate / SECONDS_IN_DAY;
        if (daysLate > WITHDRAWAL_WINDOW_DAYS - 1) return MAX_PENALTY_PCT;
        uint256 pen = (uint256(1) << (daysLate + 3)) / WITHDRAWAL_WINDOW_DAYS - 1;
        
        if (pen > MAX_PENALTY_PCT) return MAX_PENALTY_PCT;
        return pen;
    }

    function _calculateMintRewardLossMax(
        uint256 cRank,
        uint256 term,
        uint256 amplifier,
        uint256 eeaRate
    ) private view returns (uint256) {
        uint256 rankDelta = Math.max(FRENPROXY.globalRank() - cRank, 2);
        uint256 EAA = (1_000 + eeaRate);
        uint256 reward = _getGrossReward(rankDelta, amplifier, term, EAA);
        return (reward * MAX_PENALTY_PCT) / 100;
    }

    function _getGrossReward(
        uint256 rankDelta,
        uint256 amplifier,
        uint256 term,
        uint256 eaa
    ) private pure returns (uint256) {
        int128 log128 = rankDelta.fromUInt().log_2();
        int128 reward128 = log128.mul(amplifier.fromUInt()).mul(term.fromUInt()).mul(eaa.fromUInt());
        return reward128.div(uint256(1_000).fromUInt()).toUInt();
    }

    function computeTermIssue(uint256 term) public view returns(uint256 ethfCost, uint256 frenLoss){
        uint256 length = MDAOPROXY.userTermLength(msg.sender, term);
        if(length==0) return (0, 0);

        uint256 odValue = 0;
        uint256 frenTotalLoss = 0;
        for(uint256 i=0; i<length; i++) {
            address botProxy = MDAOPROXY.userContracts(msg.sender, term, i);
            FrenMintInfo memory mintObj = FRENPROXY.userMints(botProxy);
            if(mintObj.maturityTs == 0) {
                continue;
            }
            uint256 penaltyValue = _penalty(block.timestamp - mintObj.maturityTs);
            if(penaltyValue == MAX_PENALTY_PCT && mintObj.maturityTs - term * SECONDS_IN_DAY <= CUTOFFTS && mintObj.term == term) {
                odValue += 1 ether;
                frenTotalLoss += _calculateMintRewardLossMax(mintObj.rank, term, mintObj.amplifier, mintObj.eaaRate);
            }
        }
        return (odValue, frenTotalLoss);
    }

    event ClaimCompensate(address indexed wallet, uint256 indexed term, uint256 ethfCost, uint256 frenLoss);
    event GetCompensate(address indexed wallet, uint256 indexed term, uint256 ethfCost, uint256 frenLoss);

    function claimTermIssue(uint256 term) external {
        require(stage == 1, "not started yet. please wait.");
        (uint256 ethfCost, uint256 frenLoss) = computeTermIssue(term);
        
        require(recordData[msg.sender][term] == 0, "should not repeat claim.");

        ethCostData[msg.sender][term] = ethfCost;
        frenLossData[msg.sender][term] = frenLoss;

        emit ClaimCompensate(msg.sender, term, ethfCost, frenLoss);
    }

    function getTermIssue(uint256 term) external {
        require(stage == 2, "not started yet. collecting data now.");
        uint256 ethfCost = ethCostData[msg.sender][term];
        uint256 frenLoss = frenLossData[msg.sender][term];

        require(ethfCost > 0 && frenLoss > 0, "no issue value.");
        require(FRENPROXY.balanceOf(address(this)) >= frenLoss, "not enough fren for this operation.");
        
        delete ethCostData[msg.sender][term];   //no reentrance
        delete frenLossData[msg.sender][term];

        recordData[msg.sender][term] = 1;
        FRENPROXY.transferFrom(address(this), msg.sender, frenLoss);

        emit GetCompensate(msg.sender, term, ethfCost, frenLoss);
    }

    function coolStage(uint256 _stage) external onlyOwner {
        require(_stage == 0 || _stage == 1 || _stage == 2);
        stage = _stage;
    }

    function withdraw() external onlyOwner {
        if(address(this).balance > 0) {
            payable(msg.sender).transfer(address(this).balance);
        }
        uint256 frenBalance = FRENPROXY.balanceOf(address(this));
        if(frenBalance > 0) {
            FRENPROXY.transferFrom(address(this), msg.sender, frenBalance);
        }
    }

    receive() external payable {}

}