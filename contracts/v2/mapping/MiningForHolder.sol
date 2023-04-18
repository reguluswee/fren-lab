// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IMapping.sol";
import "../../interfaces/IBurnRedeemable.sol";

interface BatchLogic {
    function getRoundBots(uint256 round) external view returns(address[] memory);
    function getMintingData(address wallet) external view returns(uint256[] memory);
}

contract MiningForHolder is IMapping, IBurnRedeemable, Ownable {

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId==type(IBurnRedeemable).interfaceId;
    }

    function onTokenBurned(address user, uint256 amount) external {
    }

    bytes32 public root;

    BatchLogic constant public SAVING = BatchLogic(0xe00DB880eb886aeFF535f9BFb05d8BC7FA5b5C95);
    BatchLogic constant public MULTI = BatchLogic(0x8e3f39Beb44758C004F856E1E7498bAB26CD3F3F);

    PreFren constant public PREFREN = PreFren(0x7127deeff734cE589beaD9C4edEFFc39C9128771);
    IERC20 constant public NEWFREN = IERC20(0xf81ed9cecFE069984690A30b64c9AAf5c0245C9F);

    uint256 constant public PAGESIZE = 100;

    bool public strictTrans = true;

    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) public claimData;

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

    function leaf(address _holder, uint256 _type, uint256 _round, uint256 _amount, uint256 _maturityTs) public pure returns(bytes32) {
        return keccak256(abi.encode(
            _holder, _type, _round, _amount, _maturityTs
        ));
    }

    function checkHolder(uint256 _type, uint256 _round, 
        uint256 _amount, uint256 _maturityTs, bytes32[] calldata _proof) view public returns(bool){
        return _verify(leaf(msg.sender, _type, _round, _amount, _maturityTs), _proof);
    }



    function uniQueryRounds(uint256 _type, uint256 _page) public view returns(uint256 len, uint256[] memory rounds){
        if(_type!=1 && _type!=2) {
            return (0, rounds);
        }
        
        BatchLogic proxy = (_type==1 ? SAVING : MULTI);

        uint256[] memory _rounds = proxy.getMintingData(msg.sender);
        if(_rounds.length<=PAGESIZE) {
            return (_rounds.length, _rounds);
        }
        return (_rounds.length, _getSlice(_rounds, _page));
    }

    function uniQueryProxies(uint256 _type, uint256 _round) public view returns(address[] memory proxies) {
        if(_type!=1 && _type!=2) {
            return proxies;
        }
        BatchLogic proxy = (_type==1 ? SAVING : MULTI);
        return proxy.getRoundBots(_round);
    }

    function claim(uint256 _type, uint256 _round, uint256 _amount, uint256 _maturityTs, bytes32[] calldata _proof) external {
        require(claimData[msg.sender][_type][_round] == 0, "already claimed");
        
        require(_amount > 0 && _maturityTs > 0, "invalid parameters value");
        require(block.timestamp >= _maturityTs, "invalid maturityTs");

        require(checkHolder(_type, _round, _amount, _maturityTs, _proof), "invalid address, amount or maturity time");

        require(NEWFREN.balanceOf(address(this)) >= _amount, "not enough balance, try later");

        uint256 oldFrenBalance = PREFREN.balanceOf(msg.sender);
        uint256 burnAmount = _amount;
        if(strictTrans) {
            require(oldFrenBalance >= burnAmount, "old fren balance should be more than claimed amount");
        } else {
            burnAmount = oldFrenBalance > _amount ? _amount : oldFrenBalance;
        }

        require(PREFREN.allowance(msg.sender, address(this)) >= burnAmount, "approve old fren operation failed");

        PREFREN.burn(msg.sender, burnAmount);

        claimData[msg.sender][_type][_round] = _amount;
        NEWFREN.transferFrom(address(this), msg.sender, _amount);

        emit Transfered(msg.sender, 2, _amount);
    }


    function _getSlice(uint256[] memory _rounds, uint256 _page) private pure returns(uint256[] memory ret){
        if(_rounds.length % PAGESIZE < (_page - 1)) {
            return ret;
        }
        uint256 _start = (_page - 1) * PAGESIZE;
        uint256 _end = _page * PAGESIZE > _rounds.length ? (_rounds.length - 1) : (_page * PAGESIZE - 1);

        uint256[] memory _result = new uint256[](_end - _start + 1);
        for(uint256 i=_start; i<=_end; i++) {
            _result[i] = _rounds[i];
        }
        return _result;
    }

    function _verify(bytes32 _leaf, bytes32[] memory proof) internal view returns(bool) {
        return MerkleProof.verify(proof, root, _leaf);
    }

}