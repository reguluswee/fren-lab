// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IMinter {
    event MintershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    event MinterTransfer(address indexed oldMinter, address indexed newMinter);
    
    event MintEvp(address indexed minter, uint256 burnCount, uint256 mintIndex);

    function transferMinter(address newMinter) external;

}