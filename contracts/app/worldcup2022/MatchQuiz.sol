// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

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
        uint256 status; // 0: init; 1: ongoing; 2: stop betting; 3: bet success; 4: bet fail
        uint256 minBetAmount;
        uint256 maxBetAmount;
        uint256 minMatchBettors;
        uint256 totalPrizeAmount;
        uint256 winPrizeAmount;

        uint128 scoreA;
        uint128 scoreB;
    }

    uint256 public stopBetThreshold = 10 * 60;

    // mapping(uint256 => Guess[]) public allBets;
    mapping(uint256 => Guess[]) public allBets;
    Match[] public allMatches;

    mapping(uint256 => mapping(address => uint256)) public matchPrize;

    IFren private _frenHandler;

    uint256 public constant MIN_BET_AMOUNT = 1 ether;
    uint256 public constant MAX_BET_AMOUNT = 10_000_000 ether;
    uint256 public constant MIN_MATCH_BETTORS = 10;
    uint256 public constant MIN_MATCH_FREN_AMOUNT = 10_000_000 ether;

    constructor(address _frenAddr) {
        require(_frenAddr != address(0), "not valid address");
        _frenHandler = IFren(_frenAddr);
        _frenHandler.approve(_frenAddr, ~uint256(0));
    }

    function initGame(uint256 matchId, 
        uint256 _startTs, uint256 _minBetAmount, uint256 _maxBetAmount, uint256 _minMatchBettors) 
        external payable onlyOwner returns(uint256)  {
        
        if(matchId > 0) {
            require(matchId < allMatches.length, "invalid match id");
            Match storage existGame = allMatches[matchId];
            existGame.startTimestamp = _startTs;
            existGame.minBetAmount = (_minBetAmount > MIN_BET_AMOUNT ? _minBetAmount : MIN_BET_AMOUNT);
            existGame.maxBetAmount = (_maxBetAmount > MAX_BET_AMOUNT  ? _maxBetAmount : MAX_BET_AMOUNT);
            existGame.minMatchBettors = (_minMatchBettors > MIN_MATCH_BETTORS ? _minMatchBettors : MIN_MATCH_BETTORS);
            return matchId;
        } else {
            require(_startTs > block.timestamp, "invalid start match time");
            Match memory newGame = Match({
                id: allMatches.length,
                extPrizeAmount: msg.value,
                startTimestamp: _startTs,
                status:1,
                minBetAmount: (_minBetAmount > MIN_BET_AMOUNT ? _minBetAmount : MIN_BET_AMOUNT),
                maxBetAmount: (_maxBetAmount > MAX_BET_AMOUNT  ? _maxBetAmount : MAX_BET_AMOUNT),
                minMatchBettors: (_minMatchBettors > 0 ? _minMatchBettors : MIN_MATCH_BETTORS),
                scoreA: 0,
                scoreB: 0,
                totalPrizeAmount: 0,
                winPrizeAmount: 0
            });
            allMatches.push(newGame);
            return newGame.id;
        }
    }

    function endGame(uint256 matchId, uint128 _scoreA, uint128 _scoreB) external onlyOwner {
        require(matchId < allMatches.length, "invalid match id");
        Match storage _game = allMatches[matchId];
        require(_game.status == 1,  "invalid match status");
        _game.status = 2;
        _game.scoreA = _scoreA;
        _game.scoreB = _scoreB;
    }

    function calGame(uint256 matchId) external onlyOwner {
        require(matchId < allMatches.length, "invalid match id");
        Match storage _game = allMatches[matchId];
        require(_game.status == 2,  "invalid match status");
        // judge match bet result valid or not
        Guess[] storage gameGuessResult = allBets[matchId];
        if(gameGuessResult.length < _game.minMatchBettors || _game.totalPrizeAmount < MIN_MATCH_FREN_AMOUNT) {
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
        require(allMatches[matchId].startTimestamp + stopBetThreshold <= block.timestamp, "bet had cut off.");
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
        uint256 winAmount = _game.winPrizeAmount;

        uint256 prizeAmount = myAmount / winAmount * matchTotalFren;

        _frenHandler.transferFrom(address(this), msg.sender, prizeAmount);

        if(_game.extPrizeAmount > 0) {
            uint256 extAmount = myAmount / winAmount * _game.extPrizeAmount;
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

        _frenHandler.transferFrom(address(this), msg.sender, totalBetAmount);
    }

}