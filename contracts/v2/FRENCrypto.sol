// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../Math.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "../interfaces/IStakingToken.sol";
import "../interfaces/IRankedMintingToken.sol";
import "../interfaces/IBurnableToken.sol";
import "../interfaces/IBurnRedeemable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IFrenCooker {
    function calculateAPY() external view returns (uint256);
    function luckyPrice(uint256 _ts) external view returns(uint256);
}

contract FRENCrypto is Context, IRankedMintingToken, IStakingToken, IBurnableToken, ERC20("FREN Crypto", "FREN"), Ownable {
    using Math for uint256;
    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;

    // PUBLIC CONSTANTS
    uint256 public constant SECONDS_IN_DAY = 3_600 * 24;
    uint256 public constant DAYS_IN_YEAR = 365;

    uint256 public constant MIN_TERM = 1 * SECONDS_IN_DAY - 1;
    uint256 public constant MAX_TERM_START = 100 * SECONDS_IN_DAY;
    uint256 public constant MAX_TERM_END = 1_000 * SECONDS_IN_DAY;
    uint256 public constant TERM_AMPLIFIER = 15;
    uint256 public constant TERM_AMPLIFIER_THRESHOLD = 5_000;
    uint256 public constant REWARD_AMPLIFIER_START = 3_000;
    uint256 public constant REWARD_AMPLIFIER_END = 1;
    uint256 public constant EAA_PM_START = 100;
    uint256 public constant EAA_PM_STEP = 1;
    uint256 public constant EAA_RANK_STEP = 100_000;
    uint256 public constant WITHDRAWAL_WINDOW_DAYS = 7;
    uint256 public constant MAX_PENALTY_PCT = 99;

    uint256 public constant FREN_MIN_STAKE = 0;
    uint256 public constant FREN_MIN_BURN = 0;

    uint256 public constant FREN_APY_START = 20;
    uint256 public constant FREN_APY_DAYS_STEP = 90;
    uint256 public constant FREN_APY_END = 2;

    string public constant AUTHORS = "FREN - POWP Protocol @Dr.Ran @satoshi_song @Jackie";

    uint256 public constant START_PRICE = 1 ether;
    uint256 public constant SECONDS_IN_HOUR = 60 * 60;
    uint256 public constant HOURS_IN_YEAR = 365 * 24;
    uint256 public constant SECONDS_IN_YEAR = HOURS_IN_YEAR * SECONDS_IN_HOUR;

    // PUBLIC STATE, READABLE VIA NAMESAKE GETTERS

    uint256 public immutable launchTs;
    uint256 public immutable carryBlock;

    uint256 public immutable genesisTs;
    uint256 public globalRank;
    uint256 public activeMinters;
    uint256 public activeStakes;

    uint256 public totalFrenMintTerm;
    uint256 public totalFrenStakedAmount;
    uint256 public totalFrenStakedTerm;

    mapping(address => MintInfo) public userMints;
    mapping(address => uint256) public userBurns;
    mapping(address => StakeInfo) public userStakes;

    address public stableTreasury;
    IFrenCooker public frenCooker;

    // CONSTRUCTOR
    constructor(
        uint256 _inheritRank, uint256 _inheritTs, uint256 _carryBlock,
        uint256 _preMintAmount, address _preMintHolder   /* for pre fren holder and hold by _preMintHolder address */
    ) {
        globalRank = _inheritRank;
        genesisTs = _inheritTs;
        carryBlock = _carryBlock;
        launchTs = block.timestamp;
        _mint(_preMintHolder, _preMintAmount);
    }

    /* owner method */
    function relayTreasury(address _stableTreasury) external onlyOwner {
        require(address(0) != _stableTreasury, "invalid treasury address");
        stableTreasury = _stableTreasury;
    }

    function relayCooker(address _frenCooker) external onlyOwner {
        require(address(0) != _frenCooker, "invalid cooker address");
        frenCooker = IFrenCooker(_frenCooker);
    }
    /* owner method */

    function luckyPrice(uint256 _ts) public view returns(uint256) {
        require(address(frenCooker) != address(0), "invlid cooker");
        return frenCooker.luckyPrice(_ts);
        // uint256 secTime = _ts - launchTs;
        // uint256 hourPassed = ABDKMath64x64.divu(secTime, SECONDS_IN_HOUR).toUInt();
        // if(hourPassed == 0) {
        //     return START_PRICE;
        // }

        // uint256 expN = ABDKMath64x64.divu(secTime, SECONDS_IN_YEAR).toUInt();    /* launch year towards zero */
        // uint256 baseCost = ABDKMath64x64.exp_2(ABDKMath64x64.fromUInt(expN)).toUInt() * START_PRICE;

        // uint256 dyCost = ABDKMath64x64.mulu(
        //     ABDKMath64x64.divu(baseCost, HOURS_IN_YEAR),
        //     (hourPassed - (expN) * 365 * 24)
        // );

        // return Math.max(
        //     (baseCost + dyCost),
        //     START_PRICE    
        // );
    }

    function timePrice() public view returns(uint256) {
        return luckyPrice(block.timestamp);
    }

    // INTERNAL TYPE TO DESCRIBE A FREN MINT INFO
    struct MintInfo {
        address user;
        uint256 term;
        uint256 maturityTs;
        uint256 rank;
        uint256 eaaRate;
    }

    // INTERNAL TYPE TO DESCRIBE A XEN STAKE
    struct StakeInfo {
        uint256 term;
        uint256 maturityTs;
        uint256 amount;
        uint256 apy;
    }

    // PRIVATE METHODS

    /**
     * @dev calculates current MaxTerm based on Global Rank
     *      (if Global Rank crosses over TERM_AMPLIFIER_THRESHOLD)
     */
    function _calculateMaxTerm() private view returns (uint256) {
        if (globalRank > TERM_AMPLIFIER_THRESHOLD) {
            uint256 delta = globalRank.fromUInt().log_2().mul(TERM_AMPLIFIER.fromUInt()).toUInt();
            uint256 newMax = MAX_TERM_START + delta * SECONDS_IN_DAY;
            return Math.min(newMax, MAX_TERM_END);
        }
        return MAX_TERM_START;
    }

    /**
     * @dev calculates Withdrawal Penalty depending on lateness
     */
    function _penalty(uint256 secsLate) private pure returns (uint256) {
        // =MIN(2^(daysLate+3)/window-1,99)
        uint256 daysLate = secsLate / SECONDS_IN_DAY;
        if (daysLate > WITHDRAWAL_WINDOW_DAYS - 1) return MAX_PENALTY_PCT;
        uint256 penalty = (uint256(1) << (daysLate + 3)) / WITHDRAWAL_WINDOW_DAYS - 1;
        return Math.min(penalty, MAX_PENALTY_PCT);
    }

    /**
     * @dev calculates net Mint Reward (adjusted for Penalty)
     */
    function _calculateMintReward(
        uint256 cRank,
        uint256 term,
        uint256 maturityTs,
        uint256 eeaRate
    ) private view returns (uint256) {
        uint256 secsLate = block.timestamp - maturityTs;
        uint256 penalty = _penalty(secsLate);
        uint256 rankDelta = Math.max(globalRank - cRank, 2);
        uint256 EAA = (1_000 + eeaRate);
        uint256 reward = getGrossReward(rankDelta, term, EAA);
        return (reward * (100 - penalty)) / 100;
    }

    /**
     * @dev cleans up User Mint storage (gets some Gas credit;))
     */
    function _cleanUpUserMint(uint256 _term) private {
        delete userMints[_msgSender()];
        totalFrenMintTerm = _calculateRoundingUp(
            activeMinters * totalFrenMintTerm - _term, 
            --activeMinters
        );
    }

    /**
     * @dev calculates Early Adopter Amplifier Rate (in 1/000ths)
     *      actual EAA is (1_000 + EAAR) / 1_000
     */
    function _calculateEAARate() private view returns (uint256) {
        uint256 decrease = (EAA_PM_STEP * globalRank) / EAA_RANK_STEP;
        if (decrease > EAA_PM_START) return 0;
        return EAA_PM_START - decrease;
    }

    // PUBLIC CONVENIENCE GETTERS

    /**
     * @dev calculates gross Mint Reward
     */
    function getGrossReward(
        uint256 rankDelta,
        uint256 term,
        uint256 eaa
    ) public pure returns (uint256) {
        int128 log128 = rankDelta.fromUInt().log_2();
        int128 reward128 = log128.mul(term.fromUInt()).mul(eaa.fromUInt());
        return reward128.div(uint256(1_000).fromUInt()).toUInt();
    }

    /**
     * @dev returns User Mint object associated with User account address
     */
    function getUserMint() external view returns (MintInfo memory) {
        return userMints[_msgSender()];
    }

    /**
     * @dev returns current EAA Rate
     */
    function getCurrentEAAR() external view returns (uint256) {
        return _calculateEAARate();
    }

    /**
     * @dev returns current MaxTerm
     */
    function getCurrentMaxTerm() external view returns (uint256) {
        return _calculateMaxTerm();
    }

    // PUBLIC STATE-CHANGING METHODS
    /**
     * @dev accepts User cRank claim provided all checks pass (incl. no current claim exists)
     */
    function claimRank(uint256 term) external payable {
        uint256 termSec = term * SECONDS_IN_DAY;
        require(termSec > MIN_TERM, "CRank: Term less than min");
        require(termSec < _calculateMaxTerm() + 1, "CRank: Term more than current max term");
        require(userMints[_msgSender()].rank == 0, "CRank: Mint already in progress");
        require(stableTreasury != address(0), "invalid treasury address");

        uint256 currentPrice = timePrice();
        require(msg.value == currentPrice, 'mint value not correct.');

        // create and store new MintInfo
        MintInfo memory mintInfo = MintInfo({
            user: _msgSender(),
            term: term,
            maturityTs: block.timestamp + termSec,
            rank: globalRank,
            eaaRate: _calculateEAARate()
        });
        userMints[_msgSender()] = mintInfo;

        totalFrenMintTerm = _calculateRoundingUp(
            activeMinters * totalFrenMintTerm + term, 
            ++activeMinters
        );
        
        (bool success,) = payable(stableTreasury).call{value: currentPrice}("");
        require(success, "reverted for treasury issues");
        emit RankClaimed(_msgSender(), term, globalRank++);
    }

    /**
     * @dev ends minting upon maturity (and within permitted Withdrawal Time Window), gets minted FREN
     */
    function claimMintReward() external {
        MintInfo memory mintInfo = userMints[_msgSender()];
        require(mintInfo.rank > 0, "CRank: No mint exists");
        require(block.timestamp > mintInfo.maturityTs, "CRank: Mint maturity not reached");

        // calculate reward and mint tokens
        uint256 rewardAmount = _calculateMintReward(
            mintInfo.rank,
            mintInfo.term,
            mintInfo.maturityTs,
            mintInfo.eaaRate
        ) * 1 ether;
        _mint(_msgSender(), rewardAmount);

        _cleanUpUserMint(mintInfo.term);
        emit MintClaimed(_msgSender(), rewardAmount);
    }

    /**
     * @dev  ends minting upon maturity (and within permitted Withdrawal time Window)
     *       mints FREN coins and splits them between User and designated other address
     */
    function claimMintRewardAndShare(address other, uint256 pct) external {
        MintInfo memory mintInfo = userMints[_msgSender()];
        require(other != address(0), "CRank: Cannot share with zero address");
        require(pct > 0, "CRank: Cannot share zero percent");
        require(pct < 101, "CRank: Cannot share 100+ percent");
        require(mintInfo.rank > 0, "CRank: No mint exists");
        require(block.timestamp > mintInfo.maturityTs, "CRank: Mint maturity not reached");

        // calculate reward
        uint256 rewardAmount = _calculateMintReward(
            mintInfo.rank,
            mintInfo.term,
            mintInfo.maturityTs,
            mintInfo.eaaRate
        ) * 1 ether;
        uint256 sharedReward = (rewardAmount * pct) / 100;
        uint256 ownReward = rewardAmount - sharedReward;

        // mint reward tokens
        _mint(_msgSender(), ownReward);
        _mint(other, sharedReward);

        _cleanUpUserMint(mintInfo.term);
        emit MintClaimed(_msgSender(), rewardAmount);
    }

    /**
     * @dev  ends minting upon maturity (and within permitted Withdrawal time Window)
     *       mints FREN coins and stakes 'pct' of it for 'term'
     */
    function claimMintRewardAndStake(uint256 pct, uint256 term) external {
        MintInfo memory mintInfo = userMints[_msgSender()];
        // require(pct > 0, "CRank: Cannot share zero percent");
        require(pct < 101, "CRank: Cannot share >100 percent");
        require(mintInfo.rank > 0, "CRank: No mint exists");
        require(block.timestamp > mintInfo.maturityTs, "CRank: Mint maturity not reached");

        // calculate reward
        uint256 rewardAmount = _calculateMintReward(
            mintInfo.rank,
            mintInfo.term,
            mintInfo.maturityTs,
            mintInfo.eaaRate
        ) * 1 ether;
        uint256 stakedReward = (rewardAmount * pct) / 100;
        uint256 ownReward = rewardAmount - stakedReward;

        // mint reward tokens part
        _mint(_msgSender(), ownReward);
        _cleanUpUserMint(mintInfo.term);
        emit MintClaimed(_msgSender(), rewardAmount);

        // nothing to burn since we haven't minted this part yet
        // stake extra tokens part
        require(stakedReward > FREN_MIN_STAKE, "FREN: Below min stake");
        require(term * SECONDS_IN_DAY > MIN_TERM, "FREN: Below min stake term");
        require(term * SECONDS_IN_DAY < MAX_TERM_END + 1, "FREN: Above max stake term");
        require(userStakes[_msgSender()].amount == 0, "FREN: stake exists");

        _createStake(stakedReward, term);
        emit Staked(_msgSender(), stakedReward, term);
    }

    /**
     * @dev burns FREN tokens and creates Proof-Of-Burn record to be used by connected DeFi services
     */
    function burn(address user, uint256 amount) public {
        require(amount > FREN_MIN_BURN, "Burn: Below min limit");
        require(
            IERC165(_msgSender()).supportsInterface(type(IBurnRedeemable).interfaceId),
            "Burn: not a supported contract"
        );

        _spendAllowance(user, _msgSender(), amount);
        _burn(user, amount);
        userBurns[user] += amount;
        IBurnRedeemable(_msgSender()).onTokenBurned(user, amount);
    }

    // STAKE Methods
    /**
     * @dev initiates FREN Stake in amount for a term (days)
     */
    function stake(uint256 amount, uint256 term) external {
        require(balanceOf(_msgSender()) >= amount, "FREN: not enough balance");
        require(amount > FREN_MIN_STAKE, "FREN: Below min stake");
        require(term * SECONDS_IN_DAY > MIN_TERM, "FREN: Below min stake term");
        require(term * SECONDS_IN_DAY < MAX_TERM_END + 1, "FREN: Above max stake term");
        require(userStakes[_msgSender()].amount == 0, "FREN: stake exists");

        // burn staked FREN
        _burn(_msgSender(), amount);
        // create FREN Stake
        _createStake(amount, term);
        emit Staked(_msgSender(), amount, term);
    }

    /**
     * @dev ends FREN Stake and gets reward if the Stake is mature
     */
    function withdraw() external {
        StakeInfo memory userStake = userStakes[_msgSender()];
        require(userStake.amount > 0, "FREN: no stake exists");

        uint256 frenReward = _calculateStakeReward(
            userStake.amount,
            userStake.term,
            userStake.maturityTs,
            userStake.apy
        );
        activeStakes--;

        totalFrenStakedTerm = _calculateRoundingUp(
            totalFrenStakedAmount * totalFrenStakedTerm - userStake.amount * userStake.term, 
            totalFrenStakedAmount - userStake.amount
        );

        totalFrenStakedAmount -= userStake.amount;

        // mint staked FREN (+ reward)
        _mint(_msgSender(), userStake.amount + frenReward);
        emit Withdrawn(_msgSender(), userStake.amount, frenReward);
        delete userStakes[_msgSender()];
    }

    /**
     * @dev returns FREN Stake object associated with User account address
     */
    function getUserStake() external view returns (StakeInfo memory) {
        return userStakes[_msgSender()];
    }

    /**
     * @dev returns current APY
     */
    function getCurrentAPY() external view returns (uint256) {
        return _calculateAPY();
    }

    /**
     * @dev creates User Stake
     */
    function _createStake(uint256 amount, uint256 term) private {
        userStakes[_msgSender()] = StakeInfo({
            term: term,
            maturityTs: block.timestamp + term * SECONDS_IN_DAY,
            amount: amount,
            apy: _calculateAPY()
        });
        activeStakes++;

        totalFrenStakedTerm = _calculateRoundingUp(
            totalFrenStakedAmount * totalFrenStakedTerm + amount * term, 
            totalFrenStakedAmount + amount
        );

        totalFrenStakedAmount += amount;
    }
    
    function _calculateAPY() private view returns (uint256) {
        if(address(frenCooker) == address(0)) return 0;
        return frenCooker.calculateAPY();
    }

    /**
     * @dev calculates FREN Stake Reward
     */
    function _calculateStakeReward(
        uint256 amount,
        uint256 term,
        uint256 maturityTs,
        uint256 apy
    ) private view returns (uint256) {
        if (block.timestamp > maturityTs) {
            uint256 rate = (apy * term * 1_000_000) / DAYS_IN_YEAR;
            return (amount * rate) / 100_000_000;
        }
        return 0;
    }

    function _calculateRoundingUp(uint256 a, uint256 b) private pure returns(uint256) {
        if(b == 0) {
            return 0;
        }
        if(a % b == 0) {
            return ABDKMath64x64.divu(a, b).toUInt();
        } else {
            return ABDKMath64x64.add(ABDKMath64x64.divu(a, b), ABDKMath64x64.fromUInt(1)).toUInt();
        }
    }
}
