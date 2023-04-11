// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IMapping.sol";
import "../../interfaces/IBurnRedeemable.sol";

contract StakeForHolder is IMapping, IBurnRedeemable, Ownable {

    struct TermInfo {
        uint256 maturityTs;
        uint256 amount;
        bool done;
    }

    bytes32 public root;

    mapping(address => TermInfo) public claimData;

    PreFren constant public PREFREN = PreFren(0x7127deeff734cE589beaD9C4edEFFc39C9128771);

    IERC20 constant public NEWFREN = IERC20(0xf81ed9cecFE069984690A30b64c9AAf5c0245C9F);

    bool public strictTrans = true;

    constructor(bytes32 _root) {
        root = _root;
        NEWFREN.approve(address(this), ~uint256(0));
    }

    function modifyStrict(bool _check) external onlyOwner {
        strictTrans = _check;
    }

    function modifyRoot(bytes32 _root) external onlyOwner {
        root = _root;
    }

    function drawback() external onlyOwner {
        NEWFREN.transferFrom(address(this), msg.sender, NEWFREN.balanceOf(address(this)));
    }

    function checkHolder(uint256 _amount, uint256 _maturityTs, bytes32[] calldata _proof) view public returns(bool){
        return _verify(leaf(msg.sender, _amount, _maturityTs), _proof);
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId==type(IBurnRedeemable).interfaceId;
    }

    function onTokenBurned(address user, uint256 amount) external {
    }

    function leaf(address _holder, uint256 _amount, uint256 _maturityTs) public pure returns(bytes32) {
        return keccak256(abi.encode(
            _holder, _amount, _maturityTs
        ));
    }

    function claim(uint256 _amount, uint256 _maturityTs, bytes32[] calldata _proof) external {
        require(claimData[msg.sender].amount == 0, "already claimed");
        require(_amount > 0 && _maturityTs > 0, "invalid parameters value");
        require(checkHolder(_amount, _maturityTs, _proof), "invalid address, amount or maturity time");

        uint256 oldFrenBalance = PREFREN.balanceOf(msg.sender);
        uint256 burnAmount = _amount;
        if(strictTrans) {
            require(oldFrenBalance >= burnAmount, "old fren balance should be more than claimed amount");
        } else {
            burnAmount = oldFrenBalance > _amount ? _amount : oldFrenBalance;
        }

        require(PREFREN.allowance(msg.sender, address(this)) >= burnAmount, "approve old fren operation failed");

        PREFREN.burn(msg.sender, burnAmount);

        TermInfo memory termInfo = TermInfo({
            maturityTs : _maturityTs,
            amount : _amount,
            done: false
        });

        claimData[msg.sender] = termInfo;

        emit Claimed(msg.sender, 1, _amount);
    }

    function transfer() external {
        require(!claimData[msg.sender].done, "already transfered swap");
        require(block.timestamp >= claimData[msg.sender].maturityTs, "invalid maturityTs");
        require(NEWFREN.balanceOf(address(this)) >= claimData[msg.sender].amount, "not enough balance, try later");

        claimData[msg.sender].done = true;
        NEWFREN.transferFrom(address(this), msg.sender, claimData[msg.sender].amount);

        emit Transfered(msg.sender, 1, claimData[msg.sender].amount);
    }

    function _verify(bytes32 _leaf, bytes32[] memory proof) internal view returns(bool) {
        return MerkleProof.verify(proof, root, _leaf);
    }
}