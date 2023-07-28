// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BatchTransfer {

    function batchTrans(uint256 amount, address[] calldata addressList) external payable {
        require(addressList.length > 0, "empty or zero params");
        uint256 totalAmount;
        unchecked {
            totalAmount = amount * addressList.length;
        }
        require(totalAmount > 0 && msg.value == totalAmount, "insufficient balance or allowance");

        for(uint256 i=0; i<addressList.length; i++) {
            payable(addressList[i]).transfer(amount);
        }
    }

    function batchTransToken(address tokenAddr, uint256 amount, address[] calldata addressList) external {
        require(tokenAddr != address(0) && amount > 0 && addressList.length > 0, "invalid params");

        ERC20 tokenCon = ERC20(tokenAddr);
        uint256 totalAmount;
        unchecked {
            totalAmount = amount * addressList.length;
        }
        require(totalAmount > 0 && tokenCon.balanceOf(msg.sender) >= totalAmount 
            && tokenCon.allowance(msg.sender, address(this)) >= totalAmount, "insufficient balance or allowance");
        
        for(uint256 i=0; i<addressList.length; i++) {
            tokenCon.transferFrom(msg.sender, addressList[i], amount);
        }
    }
}