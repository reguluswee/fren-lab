// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Quiz is Ownable {

    struct Game {
        uint256 gameId;
        uint256 playerA;
        uint256 playerB;
        uint256 playerC;
        string url;//详情路径
        uint256 winner;
        uint8 status;//0.初始化 1 可以押注 2.暂停押注 3.结算 4.押注废弃，各自取钱出来
        uint256 betsNumA;
        uint256 betsNumB;
        uint256 betsNumC;
        uint256 serviceFee;//9500 = 95%
        uint256 initBets;
    }

    struct Ticket {
        uint256 gameId;
        uint256 ticketId;
        uint256 betsNum;
        uint256 bet;//押注的选项
        uint256 rewards;
        uint8 status;//0.初始化 1.已经索取 2.已经退款
        bool bo;
    }

    address _betErc20;//押注的20地址
    uint256 public percent = 10000;//9500 = 95%

    Game[] public games;//所有的竞猜
    Ticket[] public tickets;//所有的押注

    constructor() {
        if (_betErc20 != address(0x0)) {
            _approveErc20(address(this), type(uint256).max);
        }
    }

    // mapping (uint256 => Game) private allGames;//gameId > game
    mapping (uint256 => uint256[]) private _gameATickets;// gameID 对应押注A数量
    mapping (uint256 => uint256[]) private _gameBTickets;// gameID 对应押注B数量
    mapping (uint256 => uint256[]) private _gameCTickets;// gameID 对应押注C数量
    mapping (address => uint256[]) private _userTickets;// 用户对对应押注的ticketsIDs
    
    //发起一个比赛
    function launchGame(uint256 pA,uint256 pB,uint256 pC,string memory url,uint8 status,uint256 serviceFee,uint256 initBets) public onlyOwner {

        bool tfResult = _transferErc20(msg.sender,address(this), initBets);

        require( tfResult, "Chargeback failure");//扣费失败

        Game memory newGame = Game({
            gameId: games.length,
            playerA: pA,
            playerB: pB,
            playerC: pC,
            winner: 0,
            url: url,
            status: status,
            betsNumA: 0,
            betsNumB: 0,
            betsNumC: 0,
            serviceFee: serviceFee,
            initBets: initBets
        });
        
        games.push(newGame);
        // allGames[newGame.gameId] = newGame;
    }

    //押注
    function betOnA(uint256 gameId,uint256 betsNum) public {

        require( games.length > gameId , "Game does not exist");
        require( games[gameId].status == 1 , "Unable to bet on status exceptions");//只有状态1 可以押注

        Ticket memory checkTicket = getTicketByGameId(msg.sender,gameId);
        require( !checkTicket.bo , "Bets have been placed and cannot be placed twice");//不能二次下注

        //先把 fren从用户账户里转移到合约地址中
        bool tfResult = _transferErc20(msg.sender,address(this),betsNum);
        require( tfResult, "Chargeback failure");//扣费失败

        Ticket memory ticket = Ticket({
            gameId: gameId,
            ticketId: tickets.length,
            betsNum: betsNum,
            bet: 1,
            rewards: 0,
            status: 0,
            bo: true
        });

        tickets.push(ticket);

        games[gameId].betsNumA += betsNum;

        uint256[] storage tempTAs = _gameATickets[gameId];
        if (tempTAs.length == 0){
            _gameATickets[gameId] = new uint256[](0);
            tempTAs = _gameATickets[gameId];
        }

        tempTAs.push(ticket.ticketId);
        _gameATickets[gameId] = tempTAs;

        uint256[] storage tempUt = _userTickets[msg.sender];
        if (tempUt.length == 0) {
            _userTickets[msg.sender] = new uint256[](0);
            tempUt = _userTickets[msg.sender];
        }

        tempUt.push(ticket.ticketId);
        _userTickets[msg.sender] = tempUt;
    }

    //押注
    function betOnB(uint256 gameId,uint256 betsNum) public {

        require( games.length > gameId , "Game does not exist");
        require( games[gameId].status == 1 , "Unable to bet on status exceptions");//只有状态1 可以押注

        Ticket memory checkTicket = getTicketByGameId(msg.sender,gameId);
        require( !checkTicket.bo , "Bets have been placed and cannot be placed twice");//不能二次下注

        bool tfResult = _transferErc20(msg.sender,address(this),betsNum);
        require( tfResult, "Chargeback failure");//扣费失败

        Ticket memory ticket = Ticket({
            gameId: gameId,
            ticketId: tickets.length,
            betsNum: betsNum,
            bet: 2,
            rewards: 0,
            status: 0,
            bo: true
        });

        tickets.push(ticket);

        games[gameId].betsNumB += betsNum;

        uint256[] storage tempTAs = _gameBTickets[gameId];
        if (tempTAs.length == 0){
            _gameBTickets[gameId] = new uint256[](0);
            tempTAs = _gameBTickets[gameId];
        }

        tempTAs.push(ticket.ticketId);
        _gameBTickets[gameId] = tempTAs;

        uint256[] storage tempUt = _userTickets[msg.sender];
        if (tempUt.length == 0) {
            _userTickets[msg.sender] = new uint256[](0);
            tempUt = _userTickets[msg.sender];
        }
        
        tempUt.push(ticket.ticketId);
        _userTickets[msg.sender] = tempUt;
    }

    //押注
    function betOnC(uint256 gameId,uint256 betsNum) public {
        require( games.length > gameId , "Game does not exist");
        require( games[gameId].status == 1 , "Unable to bet on status exceptions");//只有状态1 可以押注

        Ticket memory checkTicket = getTicketByGameId(msg.sender,gameId);
        require( !checkTicket.bo , "Bets have been placed and cannot be placed twice");//不能二次下注
        
        bool tfResult = _transferErc20(msg.sender,address(this),betsNum);
        require( tfResult, "Chargeback failure");//扣费失败

        Ticket memory ticket = Ticket({
            gameId: gameId,
            ticketId: tickets.length,
            betsNum: betsNum,
            bet: 2,
            rewards: 0,
            status: 0,
            bo: true
        });

        tickets.push(ticket);

        games[gameId].betsNumC += betsNum;

        uint256[] storage tempTAs = _gameCTickets[gameId];
        if (tempTAs.length == 0){
            _gameCTickets[gameId] = new uint256[](0);
            tempTAs = _gameCTickets[gameId];
        }

        tempTAs.push(ticket.ticketId);
        _gameCTickets[gameId] = tempTAs;

        uint256[] storage tempUt = _userTickets[msg.sender];
        if (tempUt.length == 0) {
            _userTickets[msg.sender] = new uint256[](0);
            tempUt = _userTickets[msg.sender];
        }
        
        tempUt.push(ticket.ticketId);
        _userTickets[msg.sender] = tempUt;
    }

    //获取到比赛的详情
    function getGameById(uint256 gameId) public view returns (Game memory,Ticket[] memory,Ticket[] memory,Ticket[] memory) {
        require( games.length > gameId , "Game does not exist");

        Game memory game = games[gameId];

        uint256[] memory gAIds = _gameATickets[gameId];
        uint256[] memory gBIds = _gameBTickets[gameId];
        uint256[] memory gCIds = _gameCTickets[gameId];

        Ticket[] memory retTA = new Ticket[](gAIds.length);
        Ticket[] memory retTB = new Ticket[](gBIds.length);
        Ticket[] memory retTC = new Ticket[](gBIds.length);

        for (uint256 i = 0; i < gAIds.length; i++) {//获取到所有的A结果
            retTA[i] = tickets[gAIds[i]];
        }

        for (uint256 i = 0; i < gBIds.length; i++) {//获取到所有的B结果
            retTB[i] = tickets[gBIds[i]];
        }

        for (uint256 i = 0; i < gCIds.length; i++) {//获取到所有的B结果
            retTC[i] = tickets[gCIds[i]];
        }

        return (game,retTA,retTB,retTC);
    }

    //获取到某个用户押注比赛的详情
    function getTicketByGameId(address addr,uint256 gameId) public view returns (Ticket memory) {
        require( games.length > gameId , "Game does not exist");

        uint256[] memory tempUt = _userTickets[addr];

        Ticket memory tempTicket;

        for (uint256 i = 0;i < tempUt.length;i++){
             if (tickets[tempUt[i]].gameId == gameId) {
                 tempTicket = tickets[tempUt[i]];
                 break;
             }
        }
        return tempTicket;
    }

    //停止押注
    function stopBet(uint256 gameId) public onlyOwner {
        require( games.length > gameId , "Game does not exist");
        require( games[gameId].status == 1, "Status abnormal, cannot be operated");//状态3、4都无法操作
        games[gameId].status = 2;
    }

    //取消一个比赛
    function cancelGame(uint256 gameId) public onlyOwner {
        require( games.length > gameId , "Game does not exist");
        require( games[gameId].status != 3 && games[gameId].status != 4, "Status abnormal, cannot be operated");//状态3、4都无法操作

        bool tfResult = _transferErc20(address(this), msg.sender, games[gameId].initBets);
        require( tfResult, "Chargeback failure");//扣费失败

        games[gameId].status = 4;
    }

    //开奖
    function openPrize(uint256 gameId,uint256 winner) public onlyOwner {

        require( games.length > gameId , "Game does not exist");
        require( winner == 1 || winner == 2 || winner == 3, "Parameter Exception");
        require( games[gameId].status == 2, "Status abnormal, cannot be operated");//未到暂停押注 就不能开奖

        if (winner == 1) {
            games[gameId].winner = games[gameId].playerA;
        } else if (winner == 2) {
            games[gameId].winner = games[gameId].playerB;
        } else if (winner == 3) {
            games[gameId].winner = games[gameId].playerC;
        }

        games[gameId].status = 3;
    }

    //claim所有的奖励
    function claimPrize() public {
        uint256[] memory tempUt = _userTickets[msg.sender];
        uint256 rewards = 0;
        uint256 bets = 0;

        for (uint256 i = 0;i < tempUt.length;i++){
            Ticket memory tempTicket = tickets[tempUt[i]];
            Game memory tempGame = games[tempTicket.gameId];

            if (tempGame.status == 3 && tempGame.winner == tempTicket.bet && tempTicket.status == 0) {//已经开奖且押注等于优胜者
                if (tempGame.winner == tempGame.playerA) {// A 获胜 就是 bet * 1 + b/a

                    uint256 tempReward = _calculationOfRewards(tempGame.betsNumB + tempGame.betsNumC + tempGame.initBets,tempGame.betsNumA,tempTicket.betsNum,tempGame.serviceFee);
                    rewards += tempReward;
                    bets += tempTicket.betsNum;
                    tickets[tempUt[i]].status = 1;
                    tickets[tempUt[i]].rewards = tempReward;
                } else if (tempGame.winner == tempGame.playerB) {
                    uint256 tempReward = _calculationOfRewards(tempGame.betsNumA + tempGame.betsNumC + tempGame.initBets,tempGame.betsNumB,tempTicket.betsNum,tempGame.serviceFee);
                    rewards += tempReward;
                    bets += tempTicket.betsNum;
                    tickets[tempUt[i]].status = 1;
                    tickets[tempUt[i]].rewards = tempReward;
                } else if (tempGame.winner == tempGame.playerC) {
                    uint256 tempReward = _calculationOfRewards(tempGame.betsNumA + tempGame.betsNumB + tempGame.initBets,tempGame.betsNumC,tempTicket.betsNum,tempGame.serviceFee);
                    rewards += tempReward;
                    bets += tempTicket.betsNum;
                    tickets[tempUt[i]].status = 1;
                    tickets[tempUt[i]].rewards = tempReward;
                }
            }
        }

        require( (rewards + bets) > 0, "No need to claim");

        bool tfResult = _transferErc20(address(this),msg.sender,rewards + bets);

        require( tfResult, "Claim failure");//扣费失败
    }

    //查询
    function checkPrize(address addr) public view returns (uint256,uint256) {
        
        if (addr == address(0x0)) {
            addr = msg.sender;
        }

        uint256[] memory tempUt = _userTickets[addr];
        uint256 rewards = 0;
        uint256 bets = 0;

        for (uint256 i = 0;i < tempUt.length;i++){
            Ticket memory tempTicket = tickets[tempUt[i]];
            Game memory tempGame = games[tempTicket.gameId];

            if (tempGame.status == 3 && tempGame.winner == tempTicket.bet && tempTicket.status == 0) {//已经开奖且押注等于优胜者
                if (tempGame.winner == tempGame.playerA) {// A 获胜 就是 bet * 1 + b/a

                    uint256 tempReward = _calculationOfRewards(tempGame.betsNumB + tempGame.betsNumC + tempGame.initBets,tempGame.betsNumA,tempTicket.betsNum,tempGame.serviceFee);
                    rewards += tempReward;
                    bets += tempTicket.betsNum;
                } else if (tempGame.winner == tempGame.playerB) {
                    uint256 tempReward = _calculationOfRewards(tempGame.betsNumA + tempGame.betsNumC + tempGame.initBets,tempGame.betsNumB,tempTicket.betsNum,tempGame.serviceFee);
                    rewards += tempReward;
                    bets += tempTicket.betsNum;
                } else if (tempGame.winner == tempGame.playerC) {
                    uint256 tempReward = _calculationOfRewards(tempGame.betsNumA + tempGame.betsNumB + tempGame.initBets,tempGame.betsNumC,tempTicket.betsNum,tempGame.serviceFee);
                    rewards += tempReward;
                    bets += tempTicket.betsNum;
                }
            }
        }

        return (bets,rewards);
    }

    //索取取消的比赛的押注
    function checkBet() public view returns (uint256){
        uint256[] memory tempUt = _userTickets[msg.sender];
        uint256 bets = 0;

        for (uint256 i = 0;i < tempUt.length;i++){
            Ticket memory tempTicket = tickets[tempUt[i]];
            Game memory tempGame = games[tempTicket.gameId];

            if (tempGame.status == 4 && tempTicket.status == 0) {//索取所有已经取消比赛的押注
                bets += tempTicket.bet;
            }
        }

        return bets;
    }

    //索取取消的比赛的押注
    function claimBet() public {
        uint256[] memory tempUt = _userTickets[msg.sender];
        uint256 bets = 0;

        for (uint256 i = 0;i < tempUt.length;i++){
            Ticket memory tempTicket = tickets[tempUt[i]];
            Game memory tempGame = games[tempTicket.gameId];

            if (tempGame.status == 4 && tempTicket.status == 0) {//索取所有已经取消比赛的押注
                bets += tempTicket.bet;
                tickets[tempUt[i]].status = 2;
                tickets[tempUt[i]].rewards = 0;
            }
        }

        require( bets > 0, "No need to claim");//扣费失败

        bool tfResult = _transferErc20(address(this),msg.sender,bets);

        require( tfResult, "Claim failure");//扣费失败

    }

    //提现
    function withdraw(uint256 balance) public onlyOwner {
        // uint256 balance = _balanceOfErc20(address(this));

        bool tfResult = _transferErc20(address(this),msg.sender, balance);

        require( tfResult, "withdraw failure");//扣费失败
    }

    function _calculationOfRewards(uint256 loser,uint256 winner,uint256 betsNum,uint256 serviceFee) private view returns (uint256) {
        uint256 res = SafeMath.div(SafeMath.mul(loser,betsNum),winner);//奖池金额 / 奖池总押注份数 * 我押注份数 = 奖池金额 * 我押注份数 / 奖池总押注份数 = 我应该拿到的份数数
        res = SafeMath.div(SafeMath.mul(res,serviceFee),percent);// 最后获得奖励 /10000 * 9500 = 最后获得奖励 * 9500 /10000 = 百分之95的奖励金额
        return res;
    } 

    function setBetType(address erc) public onlyOwner {
        _betErc20 = erc;
        _approveErc20(address(this), type(uint256).max);
    }

    function setPercent(uint256 p) public onlyOwner {
        percent = p;
    }

    //扣除费用
    function _transferErc20(address form, address to, uint256 amount) private returns(bool){
        bytes32 a = keccak256("transferFrom(address,address,uint256)");
        bytes4 methodId = bytes4(a);
        bytes memory b = abi.encodeWithSelector(methodId, form, to, amount);
        (bool result,) = _betErc20.call(b);
        return result;
    }

    //授权扣费
    function _approveErc20(address spender, uint256 amount) private returns(bool){
        bytes32 a = keccak256("approve(address,uint256)");
        bytes4 methodId = bytes4(a);
        bytes memory b = abi.encodeWithSelector(methodId, spender, amount);
        (bool result,) = _betErc20.call(b);
        return result;
    }

    //余额
    // function _balanceOfErc20(address _owner) private returns(uint256){
    //     bytes32 a = keccak256("balanceOf(address)");
    //     bytes4 methodId = bytes4(a);
    //     bytes memory b = abi.encodeWithSelector(methodId, _owner);
    //     (uint256 result,) = _betErc20.call(b);
    //     return result;
    // }
}