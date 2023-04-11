// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IMapping.sol";
import "../../interfaces/IBurnRedeemable.sol";

// library MerkleProof {
//     /**
//      * @dev 当通过`proof`和`leaf`重建出的`root`与给定的`root`相等时，返回`true`，数据有效。
//      * 在重建时，叶子节点对和元素对都是排序过的。
//      */
//     function verify(
//         bytes32[] memory proof,
//         bytes32 root,
//         bytes32 leaf
//     ) internal pure returns (bool) {
//         bytes32 computed = processProof(proof, leaf);
//         return computed == root;
//     }

//     /**
//      * @dev Returns 通过Merkle树用`leaf`和`proof`计算出`root`. 当重建出的`root`和给定的`root`相同时，`proof`才是有效的。
//      * 在重建时，叶子节点对和元素对都是排序过的。
//      */
//     function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
//         bytes32 computedHash = leaf;
//         for (uint256 i = 0; i < proof.length; i++) {
//             computedHash = _hashPair(computedHash, proof[i]);
//         }
//         return computedHash;
//     }

//     // Sorted Pair Hash
//     function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
//         return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
//         // return a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
//     }
// }

contract DirectForHolder is IMapping, IBurnRedeemable, Ownable {

    bytes32 public root;

    mapping(address => uint256) public transferAddress; /* 1:claimed 2:transfered */
    mapping(address => uint256) public claimedAmount;

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

    function checkHolder(uint256 _amount, bytes32[] calldata _proof) view public returns(bool){
        return _verify(leaf(msg.sender, _amount), _proof);
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId==type(IBurnRedeemable).interfaceId;
    }

    function onTokenBurned(address user, uint256 amount) external {
    }

    function leaf(address _holder, uint256 _amount) public pure returns(bytes32) {
        return keccak256(abi.encode(
            _holder, _amount
        ));
    }

    function claim(uint256 _amount, bytes32[] calldata _proof) external {
        require(transferAddress[msg.sender] == 0, "already transfered swap");
        require(_amount > 0, "invalid amount");
        require(checkHolder(_amount, _proof), "invalid address or amount");

        uint256 oldFrenBalance = PREFREN.balanceOf(msg.sender);
        uint256 burnAmount = _amount;
        if(strictTrans) {
            require(oldFrenBalance >= burnAmount, "old fren balance should be more than claimed amount");
        } else {
            burnAmount = oldFrenBalance > _amount ? _amount : oldFrenBalance;
        }

        require(PREFREN.allowance(msg.sender, address(this)) >= burnAmount, "approve old fren operation failed");

        PREFREN.burn(msg.sender, burnAmount);

        transferAddress[msg.sender] = 1;
        claimedAmount[msg.sender] = _amount;

        emit Claimed(msg.sender, 0, _amount);
    }

    function transfer() external {
        require(transferAddress[msg.sender] == 1, "already transfered swap");
        require(claimedAmount[msg.sender] > 0, "invalid amount");
        require(NEWFREN.balanceOf(address(this)) >= claimedAmount[msg.sender], "not enough balance, try later");

        transferAddress[msg.sender] = 2;
        NEWFREN.transferFrom(address(this), msg.sender, claimedAmount[msg.sender]);

        emit Transfered(msg.sender, 0, claimedAmount[msg.sender]);
    }

    function _verify(bytes32 _leaf, bytes32[] memory proof) internal view returns(bool) {
        return MerkleProof.verify(proof, root, _leaf);
    }

    function _uintToBytes(uint256 _x) internal pure returns(bytes memory b) {
        b = new bytes(32);
        assembly {
            mstore(add(b, 32), _x)
        }
    }

    function _addressToBytes(address _addr) internal pure returns(bytes memory b) {
        assembly {
            let m := mload(0x40)
            _addr := and(_addr, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            mstore(add(m, 20), xor(0x140000000000000000000000000000000000000000, _addr))
            mstore(0x40, add(m, 52))
            b := m
        }
    }
}