// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "abdk-libraries-solidity/ABDKMath64x64.sol";

interface IFren{
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract MatchQuiz is Ownable, ReentrancyGuard {
    struct Guess {
        address bettor;
        uint256 frenAmount;
        uint128 guessScoreA;
        uint128 guessScoreB;
    }
    struct Match {
        uint256 id;
        uint256 extPrizeAmount; //ethf
        uint256 startTimestamp;
        uint256 status; // 0: init; 1: ongoing; 2: stop betting; 3: bet fail; 4: bet success
        uint256 minBetAmount;
        uint256 maxBetAmount;
        uint256 minMatchBettors;
        uint256 minMatchFren;
        uint256 totalPrizeAmount;
        uint256 winPrizeAmount;

        uint128 scoreA;
        uint128 scoreB;
    }

    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;

    uint256 public stopBetThreshold = 10 * 60;

    // mapping(uint256 => Guess[]) public allBets;
    mapping(uint256 => Guess[]) public allBets;
    Match[] public allMatches;

    mapping(uint256 => mapping(address => uint256)) public matchPrize;

    IFren private _frenHandler;

    uint256 public constant MIN_BET_AMOUNT = 1 ether;
    uint256 public constant MAX_BET_AMOUNT = 10_000_000 ether;
    uint256 public constant MIN_MATCH_BETTORS = 10;

    constructor(address _frenAddr) {
        require(_frenAddr != address(0), "not valid address");
        _frenHandler = IFren(_frenAddr);
        _frenHandler.approve(address(this), ~uint256(0));
    }

    function initGame(uint256 _startTs, uint256 _minBetAmount, uint256 _maxBetAmount, uint256 _minMatchBettors, uint256 _minMatchFren) 
        external payable onlyOwner returns(uint256)  {
        Match memory newGame = Match({
            id: allMatches.length,
            extPrizeAmount: msg.value,
            startTimestamp: _startTs,
            status:0,
            minBetAmount: (_minBetAmount > MIN_BET_AMOUNT ? _minBetAmount : MIN_BET_AMOUNT),
            maxBetAmount: (_maxBetAmount > MAX_BET_AMOUNT  ? _maxBetAmount : MAX_BET_AMOUNT),
            minMatchBettors: (_minMatchBettors > MIN_MATCH_BETTORS ? _minMatchBettors : MIN_MATCH_BETTORS),
            minMatchFren: _minMatchFren,
            scoreA: 0,
            scoreB: 0,
            totalPrizeAmount: 0,
            winPrizeAmount: 0
        });
        allMatches.push(newGame);
        return newGame.id;
    }

    function modifyGame(uint256 matchId, uint256 _startTs, uint256 _minBetAmount, uint256 _maxBetAmount, uint256 _minMatchBettors, uint256 _minMatchFren, uint256 _status) 
        external payable onlyOwner returns(uint256) {
        Match storage _m = allMatches[matchId];
        require(_m.startTimestamp > 0, "not exist match id.");
        require(_m.status == 0 || _m.status == 1, "invalid status to modify.");
        _m.startTimestamp = _startTs;
        _m.minBetAmount = _minBetAmount;
        _m.maxBetAmount = _maxBetAmount;
        _m.status = _status;
        _m.minMatchBettors = _minMatchBettors;
        _m.minMatchFren = _minMatchFren;
        if(msg.value > 0) {
            _m.extPrizeAmount += msg.value;
        }
        return _m.id;
    }

    function endGame(uint256 matchId, uint128 _scoreA, uint128 _scoreB) external onlyOwner {
        require(matchId < allMatches.length, "invalid match id");
        Match storage _game = allMatches[matchId];
        require(_game.status == 1,  "invalid match status");
        _game.status = 2;
        _game.scoreA = _scoreA;
        _game.scoreB = _scoreB;
        _calGame(matchId);
    }

    function _calGame(uint256 matchId) internal {
        require(matchId < allMatches.length, "invalid match id");
        Match storage _game = allMatches[matchId];
        require(_game.status == 2,  "invalid match status");
        // judge match bet result valid or not
        Guess[] storage gameGuessResult = allBets[matchId];
        if(gameGuessResult.length < _game.minMatchBettors || _game.totalPrizeAmount < _game.minMatchFren) {
            _game.status = 3;
            return;
        }
        for(uint i=0; i< gameGuessResult.length; i++) {
            if(gameGuessResult[i].guessScoreA == _game.scoreA && gameGuessResult[i].guessScoreB == _game.scoreB) {
                // addin 
                matchPrize[matchId][gameGuessResult[i].bettor] += gameGuessResult[i].frenAmount;    //add quato of bettor
                allMatches[matchId].winPrizeAmount += gameGuessResult[i].frenAmount;
            }
        }
        _game.status = 4;
    }

    function withdraw() external onlyOwner nonReentrant returns(bool mainBalance, bool frenBalance){
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        uint256 balance = _frenHandler.balanceOf(address(this));
        bool frenDraw = _frenHandler.transferFrom(address(this), msg.sender, balance);
        
        return (success, frenDraw);
    }

    function betGame(uint256 matchId, uint128 scoreA, uint128 scoreB, uint256 betAmount) external returns(bool) {
        require(matchId < allMatches.length, "invalid match id.");
        require(allMatches[matchId].status == 1, "invalid match status");
        require(allMatches[matchId].startTimestamp + stopBetThreshold >= block.timestamp, "bet had cut off.");
        require(scoreA<20 && scoreB<20, "invalid score parameter.");
        require(betAmount >= allMatches[matchId].minBetAmount && betAmount <= allMatches[matchId].maxBetAmount, "invalid bet amount");
        require(
            _frenHandler.transferFrom(msg.sender, address(this), betAmount),
            "not enough fren balance");
        
        Guess memory g = Guess({
            bettor: msg.sender,
            guessScoreA: scoreA,
            guessScoreB: scoreB,
            frenAmount: betAmount
        });

        allMatches[matchId].totalPrizeAmount += betAmount;
        allBets[matchId].push(g);
        return true;
    }

    function claimPrize(uint256 matchId) external {
        require(matchId < allMatches.length, "invalid match id.");
        require(allMatches[matchId].status == 4, "invalid match status");
        
        Match memory _game = allMatches[matchId];
        uint256 matchTotalFren = _game.totalPrizeAmount;

        uint256 myAmount = matchPrize[matchId][msg.sender];
        require(myAmount > 0, "sorry, you have not prize to claim.");

        uint256 winAmount = _game.winPrizeAmount;
        require(winAmount > 0 && myAmount <= winAmount, "quato error.");

        uint256 prizeAmount = matchTotalFren / winAmount * myAmount;

        matchPrize[matchId][msg.sender] = 0;    // non reentry

        bool transResult = _frenHandler.transferFrom(address(this), msg.sender, prizeAmount);
        require(transResult, "claim prize error, try later");

        if(_game.extPrizeAmount > 0) {
            uint256 extAmount = myAmount * _game.extPrizeAmount / winAmount;
            payable(msg.sender).transfer(extAmount);
        }
    }

    function claimDraw(uint256 matchId) external {
        require(matchId < allMatches.length, "invalid match id.");
        require(allMatches[matchId].status == 3, "invalid match status");

        Guess[] storage matchGuess = allBets[matchId];
        uint256 totalBetAmount = 0;
        for(uint i=0; i<matchGuess.length; i++) {
            if(matchGuess[i].bettor==msg.sender) {
                totalBetAmount += matchGuess[i].frenAmount;
                delete matchGuess[i];
            }
        }
        require(totalBetAmount > 0, "have not fren to withdraw");
        require(
            _frenHandler.transferFrom(address(this), msg.sender, totalBetAmount),
            "claim draw fail, try later");
    }

    function getMatches() public view returns(Match[] memory) {
        return allMatches;
    }

    function getMatchGuess(uint256 matchId) public view returns(Guess[] memory) {
        return allBets[matchId];
    }

}