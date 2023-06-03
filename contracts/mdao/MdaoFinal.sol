// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../v2/mapping/IMapping.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MdaoFinal is Ownable {

    IERC20 constant public NEWFREN = IERC20(0xf81ed9cecFE069984690A30b64c9AAf5c0245C9F);

    bytes32 public root;

    mapping(address => uint256) public claimData;

    event MdaoComp(address indexed user, uint256 amount);

    constructor(bytes32 _root) {
        root = _root;
        NEWFREN.approve(address(this), ~uint256(0));
    }

    function modifyRoot(bytes32 _root) external onlyOwner {
        root = _root;
    }

    function drawback() external onlyOwner {
        NEWFREN.transferFrom(address(this), msg.sender, NEWFREN.balanceOf(address(this)));
    }

    function leaf(address _holder, uint256 _amount) public pure returns(bytes32) {
        return keccak256(abi.encode(_holder, _amount));
    }

    function checkHolder(uint256 _amount, bytes32[] calldata _proof) view public returns(bool){
        return _verify(leaf(msg.sender, _amount), _proof);
    }

    function _verify(bytes32 _leaf, bytes32[] memory proof) internal view returns(bool) {
        return MerkleProof.verify(proof, root, _leaf);
    }

    function claim(uint256 _amount, bytes32[] calldata _proof) external {
        require(_amount > 0, "invalid amount value");
        require(claimData[msg.sender] == 0, "already claimed");

        require(checkHolder(_amount, _proof), "invalid address, amount");

        require(NEWFREN.balanceOf(address(this)) >= _amount, "not enough balance, try later");

        claimData[msg.sender] = _amount;
        NEWFREN.transferFrom(address(this), msg.sender, _amount);

        emit MdaoComp(msg.sender, _amount);
    }
}