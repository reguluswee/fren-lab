// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IBurnRedeemable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IMemorySwap {
    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external payable
        returns (uint[] memory amounts);
}

abstract contract AbsFREN {
    function burn(address user, uint256 amount) public virtual;
    function approve(address spender, uint256 amount) public virtual returns (bool);

}

/**
transfer from FREN$ mint cost 60% to this contract, but could reset
 */
contract TreasuryOne is Ownable, ReentrancyGuard, IBurnRedeemable, IERC165 {

    using ABDKMath64x64 for uint256;

    AbsFREN public constant FRENTOKEN = AbsFREN(0x7127deeff734cE589beaD9C4edEFFc39C9128771);
    IMemorySwap private _swapContract = IMemorySwap(0x0980185E2E5e41EdAf71e0Da5c37a8448F213Fb3);

    uint256 public devQuato = 60;
    uint256 public maxIn = 10 ether;
    address public devWallet = 0x0926c669CC58E83Da4b9F97ceF30f508500732a6;

    constructor() {
        FRENTOKEN.approve(address(this), type(uint256).max);
    }

    event CommonAmount(string key, uint256 data);
    event CommonString(string key, string data);

    function exeBuyFREN(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) 
        external payable onlyOwner returns(uint[] memory) {
        
        uint256 availableBal = address(this).balance > maxIn ? maxIn : address(this).balance;

        unchecked {
            if(devQuato > 0) {
                uint256 devAmount = availableBal * 10 / devQuato;
                availableBal = availableBal - devAmount;    //forbid reentry
                payable(devWallet).transfer(devAmount);
            }
        }

        uint[] memory amounts = _swapContract.swapExactETHForTokens{value: availableBal}(amountOutMin, path, to, deadline);

        uint256 getFren = amounts[1];
        FRENTOKEN.burn(address(this), getFren);

        emit CommonAmount("exeBuyFREN", amountOutMin);

        return amounts;
    }
    
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId==type(IBurnRedeemable).interfaceId;
    }

    function onTokenBurned(address user, uint256 amount) external {
    }

    /************** sys function design *****************/
    event MintReceive(address indexed from, uint256 indexed value);
    receive() external payable {
        emit MintReceive(tx.origin, msg.value);
    }

    function withdraw() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function relayQuato(uint256 _quato) external onlyOwner {
        require(_quato <= 100 && _quato >= 0, "new quato is not correct.");
        devQuato = _quato;
    }

    function relayWallet(address _wallet) external onlyOwner {
        require(_wallet != address(0) , "not correct wallet address.");
        devWallet = _wallet;
    }

    function relayMaxIn(uint256 _maxIn) external onlyOwner {
        require(_maxIn > 0, "max buy in should more than zero.");
        maxIn = _maxIn;
    }

}