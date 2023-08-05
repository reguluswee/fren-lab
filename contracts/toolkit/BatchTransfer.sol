// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/*
 * @dev Jackie
 * Multichain coin and tokens transfer Tool
 * Fren holders more effective and convinent
 * More cheaper than other tools event you're not $fren Holder
 * Different Chain for different fee
 */
contract BatchTransfer {

    struct TokenUser {
        string name;
        string symbol;
        uint256 decimals;
        uint256 totalSupply;
        uint256 allowance;
        uint256 balance;
        uint256 frenBalance;
        uint256 frenAllowance;
        uint256 coinFee;
        uint256 frenFee;
        uint256 useToken;
    }

    uint256 public coinFee; // = 0.01 ether;
    uint256 public frenMinimum; // = 10_000_000 ether;
    uint256 public frenFee; // = 880_000 ether;
    
    ERC20 public frenToken;
    address public owner;
    address public cashier;

    event ChangeParam(uint256 _coinFee, uint256 _frenMinimum, uint256 _frenFee);
    event ChangeOwner(address _newHod);
    event ChangeCashier(address _newCashier);
    event BatchTrans(address indexed user, address indexed token, uint256 totalAmount, uint256 numbers);

    constructor(address _frenAddr, uint256 _coinFee, uint256 _frenMinimum, uint256 _frenFee) {
        frenToken = ERC20(_frenAddr);
        coinFee = _coinFee;
        frenMinimum = _frenMinimum;
        frenFee = _frenFee;
        owner = msg.sender;
        cashier = owner;
    }

    modifier opByDep() {
        require(msg.sender == owner);
        _;
    }

    function opParam(uint256 _coinFee, uint256 _frenMinimum, uint256 _frenFee) external opByDep {
        coinFee = _coinFee;
        frenMinimum = _frenMinimum;
        frenFee = _frenFee;
        emit ChangeParam(_coinFee, _frenMinimum, _frenFee);
    }

    function opOwner(address _newHod) external opByDep {
        if(_newHod != address(0)) {
            owner = _newHod;
            emit ChangeOwner(_newHod);
        }
    }

    function transCashier(address _newPayAddr) external opByDep {
        cashier = _newPayAddr;
        emit ChangeCashier(_newPayAddr);
    }

    function getTokenInfo(address _tokenAddr, address _spenderAddr) public view 
        returns(TokenUser memory data){
        data.coinFee = coinFee;
        data.frenFee = frenFee;
        if(_tokenAddr == address(0)) {
            if(msg.sender != address(0)) {
                data.frenBalance = frenToken.balanceOf(msg.sender);
            }
            if(_spenderAddr != address(0)) {
                data.frenAllowance = frenToken.allowance(msg.sender, _spenderAddr);
            }
            return data;
        }
        ERC20 _token_ = ERC20(_tokenAddr);
        data.name = _token_.name();
        data.symbol = _token_.symbol();
        data.decimals = _token_.decimals();
        data.totalSupply = _token_.totalSupply();
        if(msg.sender != address(0)) {
            data.balance = _token_.balanceOf(msg.sender);
            data.frenBalance = frenToken.balanceOf(msg.sender);
            data.allowance = _token_.allowance(msg.sender, _spenderAddr);
            data.frenAllowance = frenToken.allowance(msg.sender, _spenderAddr);

            if(data.frenBalance >= frenMinimum) {
                data.useToken = 1;
            }
        }

        return data;
    }

    function _regaSender() internal view returns(bool) {
        if(frenToken.balanceOf(msg.sender) < frenMinimum) {
            return false;
        }
        return true;
    }

    /* Batch Transfer Coin */
    function transEq(uint256 amount, address[] calldata addressList) external payable {
        require(addressList.length > 0, "empty or zero params");
        uint256 totalAmount = amount * addressList.length;

        if(!_regaSender()) {
            require(totalAmount > 0 && msg.value == totalAmount + coinFee, "insufficient balance with fee");
            if(coinFee > 0) {
                payable(cashier).transfer(coinFee);
            }
        } else {
            require(totalAmount > 0 && msg.value == totalAmount, "insufficient balance");
            if(frenFee > 0) {
                require(frenToken.transferFrom(msg.sender, cashier, frenFee), "failed for insufficient allowance for fee");
            }
        }

        for(uint256 i=0; i<addressList.length; i++) {
            payable(addressList[i]).transfer(amount);
        }
        emit BatchTrans(msg.sender, address(0), totalAmount, addressList.length);
    }

    function transDiff(uint256[] calldata amounts, address[] calldata addressList) external payable {
        require(addressList.length > 0, "empty or zero params");
        require(amounts.length == addressList.length, "should be equal");
        uint256 totalAmount;
        for(uint256 i=0; i<amounts.length; i++) {
            totalAmount += amounts[i];
        }
        if(!_regaSender()) {
            require(totalAmount > 0 && msg.value == totalAmount + coinFee, "insufficient balance with fee");
            if(coinFee > 0) {
                payable(cashier).transfer(coinFee);
            }
        } else {
            require(totalAmount > 0 && msg.value == totalAmount, "insufficient balance");
            if(frenFee > 0) {
                require(frenToken.transferFrom(msg.sender, cashier, frenFee), "failed for insufficient balance or allowance for fee");
            }
        }

        for(uint256 i=0; i<addressList.length; i++) {
            payable(addressList[i]).transfer(amounts[i]);
        }
        emit BatchTrans(msg.sender, address(0), totalAmount, addressList.length);
    }
    /* Batch Transfer Coin */

    /* Batch Transfer Non-Fren Token */
    function transTokenEq(address tokenAddr, uint256 amount, address[] calldata addressList) external payable {
        require(tokenAddr != address(0) && amount > 0 && addressList.length > 0, "invalid params");

        ERC20 tokenCon = ERC20(tokenAddr);
        uint256 totalAmount;
        unchecked {
            totalAmount = amount * addressList.length;
        }
        require(totalAmount > 0 && 
            tokenCon.balanceOf(msg.sender) >= totalAmount && 
            tokenCon.allowance(msg.sender, address(this)) >= totalAmount, "insufficient balance or allowance");
        
        if(!_regaSender()) {
            require(msg.value == coinFee, "insufficient balance for fee");
            if(coinFee > 0) {
                payable(cashier).transfer(coinFee);
            }
        } else {
            if(frenFee > 0) {
                require(frenToken.transferFrom(msg.sender, cashier, frenFee), "failed for insufficient balance or allowance for fee");
            }
        }
        
        for(uint256 i=0; i<addressList.length; i++) {
            tokenCon.transferFrom(msg.sender, addressList[i], amount);
        }
        emit BatchTrans(msg.sender, tokenAddr, totalAmount, addressList.length);
    }

    function transTokenDiff(address tokenAddr, uint256[] calldata amounts, address[] calldata addressList) external payable {
        require(tokenAddr != address(0) && amounts.length == addressList.length && addressList.length > 0, "invalid params");

        ERC20 tokenCon = ERC20(tokenAddr);
        uint256 totalAmount;
        for(uint256 i=0; i<amounts.length; i++) {
            totalAmount += amounts[i];
        }

        require(totalAmount > 0 && 
            tokenCon.balanceOf(msg.sender) >= totalAmount && 
            tokenCon.allowance(msg.sender, address(this)) >= totalAmount, "insufficient balance or allowance");
        
        if(!_regaSender()) {
            require(msg.value == coinFee, "insufficient balance for fee");
            if(coinFee > 0) {
                payable(cashier).transfer(coinFee);
            }
        } else {
            if(frenFee > 0) {
                require(frenToken.transferFrom(msg.sender, cashier, frenFee), "failed for insufficient balance or allowance for fee");
            }
        }
        
        for(uint256 i=0; i<addressList.length; i++) {
            tokenCon.transferFrom(msg.sender, addressList[i], amounts[i]);
        }
        emit BatchTrans(msg.sender, tokenAddr, totalAmount, addressList.length);
    }
    /* Batch Transfer Non-Fren Token */

    /* Batch Transfer Fren Token For Free */
    function transFrenEq(uint256 amount, address[] calldata addressList) external {
        require(amount > 0 && addressList.length > 0, "invalid params");
        uint256 totalAmount;
        unchecked {
            totalAmount = amount * addressList.length;
        }
        require(totalAmount > 0 && 
            frenToken.balanceOf(msg.sender) >= totalAmount && 
            frenToken.allowance(msg.sender, address(this)) >= totalAmount, "insufficient balance or allowance");
        
        for(uint256 i=0; i<addressList.length; i++) {
            frenToken.transferFrom(msg.sender, addressList[i], amount);
        }
        emit BatchTrans(msg.sender, address(frenToken), totalAmount, addressList.length);
    }

    function transFrenDiff(uint256[] calldata amounts, address[] calldata addressList) external {
        require(amounts.length == addressList.length && addressList.length > 0, "invalid params");

        uint256 totalAmount;
        for(uint256 i=0; i<amounts.length; i++) {
            totalAmount += amounts[i];
        }

        require(totalAmount > 0 && 
            frenToken.balanceOf(msg.sender) >= totalAmount && 
            frenToken.allowance(msg.sender, address(this)) >= totalAmount, "insufficient balance or allowance");
        
        for(uint256 i=0; i<addressList.length; i++) {
            frenToken.transferFrom(msg.sender, addressList[i], amounts[i]);
        }
        emit BatchTrans(msg.sender, address(frenToken), totalAmount, addressList.length);
    }
    /* Batch Transfer Fren Token For Free */
}