// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library MerkleProof {
    /**
     * @dev 当通过`proof`和`leaf`重建出的`root`与给定的`root`相等时，返回`true`，数据有效。
     * 在重建时，叶子节点对和元素对都是排序过的。
     */
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    /**
     * @dev Returns 通过Merkle树用`leaf`和`proof`计算出`root`. 当重建出的`root`和给定的`root`相同时，`proof`才是有效的。
     * 在重建时，叶子节点对和元素对都是排序过的。
     */
    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    // Sorted Pair Hash
    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }
}

contract MpcWallet is Ownable {

    bytes32 public root;

    mapping(address => bool) public claimedAddress;

    uint256 constant public REWARDAMOUNT = 50_000 * 1 ether;

    IERC20 constant public FREN = IERC20(0x7127deeff734cE589beaD9C4edEFFc39C9128771);

    constructor(bytes32 _root) {
        FREN.approve(address(this), ~uint256(0));
        root = _root;
    }

    function modifyRoot(bytes32 _root) external onlyOwner {
        root = _root;
    }

    function drawback() external onlyOwner {
        FREN.transferFrom(address(this), msg.sender, FREN.balanceOf(address(this)));
    }

    function claimReward(bytes32[] calldata proof) external {
        require(!claimedAddress[msg.sender], "already claimed rewards");
        require(_verify(_leaf(msg.sender), proof), "you are not in reward list");
        require(FREN.balanceOf(address(this)) >= REWARDAMOUNT, "not enough balance");

        claimedAddress[msg.sender] = true;
        FREN.transferFrom(address(this), msg.sender, REWARDAMOUNT);
    }

    function verifyReward(bytes32[] calldata proof) view external returns(bool){
        return _verify(_leaf(msg.sender), proof);
    }

    function _verify(bytes32 leaf, bytes32[] memory proof) internal view returns(bool) {
        return MerkleProof.verify(proof, root, leaf);
    }

    function _leaf(address sender) internal pure returns(bytes32) {
        return keccak256(abi.encodePacked(sender));
    }
}