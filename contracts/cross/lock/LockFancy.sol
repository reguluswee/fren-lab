// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LockFancy is Initializable, OwnableUpgradeable {

    struct AddressMapping {
        address user;
        uint256 amount;
    }

    IERC20 constant public FREN = IERC20(0xf81ed9cecFE069984690A30b64c9AAf5c0245C9F);

    /*
    chain id => ***
     */
    mapping(uint256 => mapping(address => uint256)) public tbdMapping;
    mapping(uint256 => AddressMapping[]) public roundMapping;

    mapping(uint256 => uint256) public chainLocking;            //current chain locking
    mapping(uint256 => bool) public tbdProcessing;              //current chain processing status for recall tx
    mapping(uint256 => uint256) public chainDistribution;       //crossed token distribution of each chain

    uint256[] public suppChains; //= [bytes("BSC"), "ARB"];

    bool public allowBack;
    bool public allowCross;
    bool public allowRecall;

    event LockFren(address indexed sender, uint256 indexed chainId, uint256 amount);
    event UnLockFren(address indexed sender, uint256 indexed chainId, uint256 amount);
    event CrossIssue(uint256 indexed chainId, uint256 amount);
    event UnLockFrenByOwner(address indexed user, uint256 indexed chainId, uint256 amount);

    function initialize() public initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();

        FREN.approve(address(this), ~uint256(0));
        suppChains.push(56);
        allowBack = false;        
        allowRecall = false;
        allowCross = true;
    }

    function lockToChain(uint256 _cc, uint256 _amount) external {
        require(allowCross, "pause cross bridger for now.");
        require(!tbdProcessing[_cc], "cross tx processing, wait for a while");
        bool suppChain = false;
        for(uint256 i = 0; i < suppChains.length; i++) {
            if(_cc == suppChains[i]) {
                suppChain = true;
                break;
            }
        }
        require(suppChain, "unsupport chain");
        require(FREN.balanceOf(msg.sender) >= _amount, "not enough balance");

        FREN.transferFrom(msg.sender, address(this), _amount);
        chainLocking[_cc] += _amount;

        tbdMapping[_cc][msg.sender] += _amount;
        AddressMapping[] storage _cRound_ = roundMapping[_cc];
        bool exist = false;
        for(uint256 i=0; i<_cRound_.length; i++) {
            if(_cRound_[i].user == msg.sender) {
                _cRound_[i].amount += _amount;
                exist = true;
                break;
            }
        }
        if(!exist) {
            AddressMapping memory _d_ = AddressMapping({
                user: msg.sender,
                amount: _amount
            });
            roundMapping[_cc].push(_d_);
        }

        emit LockFren(msg.sender, _cc, _amount);
    }

    function unLockToChainIf(uint256 _cc, uint256 _amount) external {
        require(allowRecall, "unsupport recall for now.");
        require(!tbdProcessing[_cc], "cross tx processing, unable to unlock");
        require(tbdMapping[_cc][msg.sender] >= _amount, "exceed target chain locking amount");

        bool suppChain = false;
        for(uint256 i = 0; i < suppChains.length; i++) {
            if(_cc == suppChains[i]) {
                suppChain = true;
                break;
            }
        }
        require(suppChain, "unsupport chain");

        chainLocking[_cc] -= _amount;

        tbdMapping[_cc][msg.sender] -= _amount;

        bool isTotal = false;
        if(tbdMapping[_cc][msg.sender] == 0) {
            isTotal = true;
            delete tbdMapping[_cc][msg.sender];
        }
        AddressMapping[] storage _cRound_ = roundMapping[_cc];
        for(uint256 i=0; i<_cRound_.length; i++) {
            if(_cRound_[i].user == msg.sender) {
                if(isTotal) {
                    delete _cRound_[i];
                } else {
                    if(_cRound_[i].amount <= _amount) {
                        delete _cRound_[i];
                    } else {
                        _cRound_[i].amount -= _amount;
                    }
                }
                break;
            }
        }
        
        FREN.transferFrom(address(this), msg.sender, _amount);

        emit UnLockFren(msg.sender, _cc, _amount);
    }

    function crossOut(uint256 _cc) external onlyOwner {
        require(chainLocking[_cc] > 0, "zero amount");
        require(!tbdProcessing[_cc], "cross tx processing, dont repeat");

        tbdProcessing[_cc] = true;

        uint256 thisOut = chainLocking[_cc];
        chainLocking[_cc] = 0;
        chainDistribution[_cc] += thisOut;

        // reset current round data
        AddressMapping[] storage _mapping_ = roundMapping[_cc];
        for(uint256 i=0; i<_mapping_.length; i++) {
            delete tbdMapping[_cc][_mapping_[i].user];
        }
        delete roundMapping[_cc];

        tbdProcessing[_cc] = false;
        
        emit CrossIssue(_cc, thisOut);
    }

    function alterCrossStatus(bool _status) external onlyOwner {
        allowCross = _status;
    }

    function recallByOwner(uint256 _cc, address _user, uint256 _amount) external onlyOwner {
        require(!tbdProcessing[_cc], "cross tx processing, can not recall");
        require(tbdMapping[_cc][_user] >= _amount, "exceed target chain locking amount");

        bool suppChain = false;
        for(uint256 i = 0; i < suppChains.length; i++) {
            if(_cc == suppChains[i]) {
                suppChain = true;
                break;
            }
        }
        require(suppChain, "unsupport chain");

        chainLocking[_cc] -= _amount;

        tbdMapping[_cc][_user] -= _amount;

        bool isTotal = false;
        if(tbdMapping[_cc][_user] == 0) {
            isTotal = true;
            delete tbdMapping[_cc][_user];
        }
        AddressMapping[] storage _cRound_ = roundMapping[_cc];
        for(uint256 i=0; i<_cRound_.length; i++) {
            if(_cRound_[i].user == _user) {
                if(isTotal) {
                    delete _cRound_[i];
                } else {
                    if(_cRound_[i].amount <= _amount) {
                        delete _cRound_[i];
                    } else {
                        _cRound_[i].amount -= _amount;
                    }
                }
                break;
            }
        }
        
        FREN.transferFrom(address(this), _user, _amount);

        emit UnLockFrenByOwner(_user, _cc, _amount);
    }
    
}