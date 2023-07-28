// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakeImpl is Initializable, OwnableUpgradeable {

    struct ActStakeInfo {
        uint256 amount;
        uint256 stakeTs;
        uint256 stakeTerm;
        uint256 mrr;
    }

    IERC20 constant public FREN_BSC = IERC20(0xE6A768464B042a6d029394dB1fdeF360Cb60bbEb);

    uint256 public constant SECONDS_IN_HOUR = 60 * 60;
    uint256 public constant SECONDS_IN_DAY = SECONDS_IN_HOUR * 24;
    uint256 public constant MIN_STAKE_AMOUNT = 1_000_000 ether;
    uint256 public constant MAX_STAKE_AMOUNT = 2_000_000_000 ether;

    mapping(uint256 => uint256) public stakeSel;
    mapping(address => ActStakeInfo) public userStakes;
    uint256 public activeStakes;
    uint256 public remainBalance;

    uint256 public durationDays;
    uint256 public startTs;

    event Staked(address indexed user, uint256 indexed term, uint256 stakeAmount, uint256 estimateReward);
    event Withdrawn(address indexed user, uint256 indexed term, uint256 stakeAmount, uint256 reward);

    function initialize() public initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();

        FREN_BSC.approve(address(this), ~uint256(0));
        stakeSel[3] = 3;
        stakeSel[7] = 8;
        stakeSel[15] = 18;
        stakeSel[30] = 36;

        remainBalance = 7_200_000_000 ether;
    }

    function setTsAndDura(uint256 _startTs, uint256 _duration) external onlyOwner {
        require(_startTs > block.timestamp && _duration > 0, "invalid params");
        startTs = _startTs;
        durationDays = _duration;
    }

    function addReward(uint256 rewardBalance) external onlyOwner {
        require(rewardBalance > 0);
        remainBalance += rewardBalance;
    }

    function withdraw(address _owner, uint256 _amount) external onlyOwner {
        require(_amount > 0);
        require(FREN_BSC.balanceOf(address(this)) >= _amount);
        FREN_BSC.transferFrom(address(this), _owner, _amount);
    }

    function stake(uint256 term, uint256 amount) external {
        require(amount >= MIN_STAKE_AMOUNT && amount <= MAX_STAKE_AMOUNT, "invalid stake amount");
        require(term > 0 && stakeSel[term] > 0, "invalid term option");
        require(startTs > 0 && durationDays > 0, "waiting for initialized");
        require(startTs <= block.timestamp, "waiting for activity start");
        require(startTs + durationDays * SECONDS_IN_DAY > block.timestamp, "activity had ended");
        require(userStakes[_msgSender()].amount == 0, "FREN: stake exists");

        uint256 estimateReward = amount * stakeSel[term] / 100;
        require(remainBalance >= estimateReward, "not enough reward balance");

        remainBalance -= estimateReward;
        FREN_BSC.transferFrom(_msgSender(), address(this), amount);

        _createStake(term, amount);

        emit Staked(_msgSender(), term, amount, estimateReward);
    }

    function endStake() external {
        ActStakeInfo memory stakeObj = userStakes[_msgSender()];
        require(stakeObj.amount > 0, "FREN: no stake exists");
        uint256 reward = _calculateStakeReward(stakeObj.stakeTs, stakeObj.stakeTerm, stakeObj.mrr, stakeObj.amount);
        require(reward > 0, "not yet due");
        
        FREN_BSC.transferFrom(address(this), _msgSender(), reward + stakeObj.amount);
        delete userStakes[_msgSender()];
        activeStakes--;

        emit Withdrawn(_msgSender(), stakeObj.stakeTerm, stakeObj.amount, reward);
    }
    
    function _createStake(uint256 term, uint256 amount) private {
        userStakes[_msgSender()] = ActStakeInfo({
            stakeTerm: term,
            amount: amount,
            stakeTs: block.timestamp,
            mrr: stakeSel[term]
        });
        activeStakes++;
    }

    function _calculateStakeReward(uint256 stakeTs, uint256 stakeTerm, uint256 stakeMrr, uint256 stakeAmount) view private returns(uint256) {
        if(stakeTs + stakeTerm * SECONDS_IN_DAY <= block.timestamp) {
            uint256 estimateReward = stakeAmount * stakeMrr / 100;
            return estimateReward;
        }
        return 0;
    }

}