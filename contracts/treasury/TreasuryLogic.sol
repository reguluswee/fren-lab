// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../interfaces/IBurnRedeemable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../common/Utility.sol";

interface IOriSwap {
    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external payable
        returns (uint[] memory amounts);
}

abstract contract AbsFREN is Ut20{
    function burn(address user, uint256 amount) public virtual;
}

contract TreasuryLogic is IBurnRedeemable, IERC165, Initializable, OwnableUpgradeable {

    using ABDKMath64x64 for uint256;

    AbsFREN public constant FRENTOKEN = AbsFREN(0xf81ed9cecFE069984690A30b64c9AAf5c0245C9F);
    address public constant TARGETDEX = 0x74f743b803080Dd6Ed85eEf9D58826f35317FbA4;  //OriSwap
    address public constant DEVWALLET = 0x0926c669CC58E83Da4b9F97ceF30f508500732a6;
    uint256 private constant _MAXBUYIN = 20 ether;
    uint256 private constant _MINBUYIN = 1_000;
    uint256 private constant _PERIODSEC_ = 2 * 60 * 60;
    uint256 public constant PAGESIZE = 100;

    /* event defined area */
    event BuyBack(address indexed _targetDex, uint256 buyAmount, uint256 getAmount);
    event SupportToken(address indexed tokenAddr);
    event EmptyBuyBack();

    /* fixed order storage */
    uint256 private _lastBuyBackTs;

    address[] public treasuryTokenArray;
    mapping(address => uint256) public treasuryTokenMap;
    /* fixed order storage */

    function initialize() public initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId==type(IBurnRedeemable).interfaceId;
    }

    function onTokenBurned(address user, uint256 amount) external {}


    modifier canBuyIn() {
        if(block.timestamp - _lastBuyBackTs > _PERIODSEC_) {
            _;
        } else {
            if((block.timestamp - _lastBuyBackTs > 600) && _computeCond()) {
                _;
            } else {
                emit EmptyBuyBack();
            }
        }
    }

    function callIn() external payable {
        _exeBuyFREN();
    }
    
    function supportTokenLength() public view returns(uint256) {
        return treasuryTokenArray.length;
    }

    function getSupportTokens(uint256 _page) public view returns(address[] memory rounds) {
        if(supportTokenLength() <= PAGESIZE) {
            return treasuryTokenArray;
        }
        address[] memory _rounds = treasuryTokenArray;
        return _getSlice(_rounds, _page);
    }

    function lastBuyTs() public view returns(uint256) {
        return _lastBuyBackTs;
    }

    /* permission methods area */
    function supportToken(address _token) external {
        if(_token != address(0) && treasuryTokenMap[_token] == 0) {
            treasuryTokenMap[_token] = 1;
            treasuryTokenArray.push(_token);
            Ut20(_token).approve(address(this), ~uint256(0));
            emit SupportToken(_token);
        }
    }

    function withdrawToken(address token, address to, uint256 amount) external {
        require(to!=address(0));
        if(token == address(0)) { //for original token
            amount = amount == 0 ? 
                address(this).balance : 
                address(this).balance > amount ? amount : address(this).balance;
            if(amount > 0) {
                payable(to).transfer(amount);
            }
        } else {
            amount = amount == 0 ? 
                Ut20(token).balanceOf(address(this)) : 
                Ut20(token).balanceOf(address(this)) > amount ? amount : Ut20(token).balanceOf(address(this));
            if(amount > 0) {
                Ut20(token).transferFrom(address(this), to, amount);
            }
        }
    }
    /* permission methods area */

    /* private methods area */
    function _computeCond() private view returns(bool){
        uint8 result = uint8(uint256(uint160(tx.origin)) & uint256(block.timestamp) & gasleft());
        return result % 3 == 0 || result % 3 == 1 || result % 3 == 2;
    }

    function _exeBuyFREN() private canBuyIn {
        uint256 availableBal = address(this).balance > _MAXBUYIN ? _MAXBUYIN : address(this).balance;

        uint256 devAmount = availableBal / 6;
        availableBal = availableBal - devAmount;    //forbid reentry
        payable(DEVWALLET).transfer(devAmount);

        uint256 _amountOutMin = _MINBUYIN;// * availableBal;
        address[] memory _path = new address[](2);
        _path[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        _path[1] = 0xf81ed9cecFE069984690A30b64c9AAf5c0245C9F;
        uint256 _deadline = block.timestamp + _PERIODSEC_;

        uint[] memory amounts = IOriSwap(TARGETDEX).swapExactETHForTokens{value: availableBal}(_amountOutMin, _path, address(this), _deadline);

        uint256 getFren = amounts[1];
        FRENTOKEN.burn(address(this), getFren);
        _lastBuyBackTs = block.timestamp;

        emit BuyBack(TARGETDEX, availableBal, getFren);
    }

    function _getSlice(address[] memory _rounds, uint256 _page) private pure returns(address[] memory ret){
        if(_rounds.length % PAGESIZE < (_page - 1)) {
            return ret;
        }
        uint256 _start = (_page - 1) * PAGESIZE;
        uint256 _end = _page * PAGESIZE > _rounds.length ? (_rounds.length - 1) : (_page * PAGESIZE - 1);

        address[] memory _result = new address[](_end - _start + 1);
        for(uint256 i=_start; i<=_end; i++) {
            _result[i] = _rounds[i];
        }
        return _result;
    }
    /* private methods area */
}