// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface PreFren {
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    function balanceOf(address account) external view returns (uint256);

    function burn(address user, uint256 amount) external;
}

interface IMapping {
    event Claimed(address indexed user, uint256 indexed code, uint256 amount);
    event Transfered(address indexed user, uint256 indexed code, uint256 amount);
}