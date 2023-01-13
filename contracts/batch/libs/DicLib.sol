// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

address constant _FRENTOKEN = 0x7127deeff734cE589beaD9C4edEFFc39C9128771;

interface PIFrenMint{
    function claimRank(uint256 term) external payable;
    function claimMintReward() external;
    function approve(address spender, uint256 amount) external returns (bool);
}

interface PIFrenReward{
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract PMinter{
    PIFrenMint constant _FREN = PIFrenMint(_FRENTOKEN);
    
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