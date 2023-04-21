// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "./MultiProxy.sol";

contract MultiAdmin is Ownable {

    function getProxyImplementation(MultiProxy proxy) public view virtual returns(address) {
        (bool success, bytes memory returndata) = address(proxy).staticcall(hex"5c60da1b"); // proxy implementation() call
        require(success);

        return abi.decode(returndata, (address));
    }

    function getProxyAdmin(MultiProxy proxy) public view virtual returns(address) {
        (bool success, bytes memory returndata) = address(proxy).staticcall(hex"f851a440"); // proxy admin() call
        require(success);

        return abi.decode(returndata, (address));
    }

    function changeProxyAdmin(MultiProxy proxy, address _newAdmin) public virtual onlyOwner {
        proxy.changeAdmin(_newAdmin);
    }

    function upgrade(MultiProxy proxy, address _newImpl) public virtual onlyOwner {
        proxy.upgradeTo(_newImpl);
    }

    function upgradeAndCall(MultiProxy proxy, address _newImpl, bytes memory data) public payable virtual onlyOwner{
        proxy.upgradeToAndCall{value: msg.value}(_newImpl, data);
    }

    function configCall(MultiProxy proxy, bytes calldata data) external onlyOwner returns (bytes memory) {
        return proxy.configCall(data);
    }

    function withdraw(MultiProxy proxy) external onlyOwner {
        proxy.withdraw();
    }

    //add custom method
    function configRootParams(MultiProxy proxy, address _ethfOracle, address _treasury) external onlyOwner {
        proxy.configRootParams(_ethfOracle, _treasury);
    }

    function configTokens(MultiProxy proxy, address tokenAddr, address oracleAddr, uint256 _enabled) external onlyOwner {
        proxy.configTokens(tokenAddr, oracleAddr, _enabled);
    }

    function grantTokenCredit(MultiProxy proxy, address tokenAddr, uint256 creditAmount, bool remove) external onlyOwner {
        proxy.grantTokenCredit(tokenAddr, creditAmount, remove);
    }
}