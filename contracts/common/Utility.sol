// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

address constant _FRENTOKEN = 0xf81ed9cecFE069984690A30b64c9AAf5c0245C9F;

interface Ut20 {
    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function timePrice() external view returns(uint256);
}

interface UtFrenMint{
    function claimRank(uint256 term) external payable;
    function claimMintReward() external;
    function approve(address spender, uint256 amount) external returns (bool);
}

interface UtFrenReward{
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract UtMinter{
    UtFrenMint constant _FREN = UtFrenMint(_FRENTOKEN);
    
    constructor() {
        _FREN.approve(msg.sender, ~uint256(0));
    }
    
    function claimRank(uint256 term) public payable {
        _FREN.claimRank{value: msg.value}(term);
    }

    function claimMintReward() public {
        _FREN.claimMintReward();
        selfdestruct(payable(tx.origin));
    }
}

interface BatchCop {
    event BatchClaim(address indexed user, uint256 times, uint256 term, uint256 price);
    event BatchReward(address indexed user, uint256 round);
}