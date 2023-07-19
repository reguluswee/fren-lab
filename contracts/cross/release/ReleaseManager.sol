// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ReleaseProxy.sol";

contract ReleaseManager is Ownable {

    function getProxyImplementation(ReleaseProxy proxy) public view virtual returns(address) {
        (bool success, bytes memory returndata) = address(proxy).staticcall(hex"5c60da1b"); // proxy implementation() call
        require(success);

        return abi.decode(returndata, (address));
    }

    function getProxyAdmin(ReleaseProxy proxy) public view virtual returns(address) {
        (bool success, bytes memory returndata) = address(proxy).staticcall(hex"f851a440"); // proxy admin() call
        require(success);

        return abi.decode(returndata, (address));
    }

    function changeProxyAdmin(ReleaseProxy proxy, address _newAdmin) public virtual onlyOwner {
        proxy.changeAdmin(_newAdmin);
    }

    function upgrade(ReleaseProxy proxy, address _newImpl) public virtual onlyOwner {
        proxy.upgradeTo(_newImpl);
    }

    function upgradeAndCall(ReleaseProxy proxy, address _newImpl, bytes memory data) public payable virtual onlyOwner{
        proxy.upgradeToAndCall{value: msg.value}(_newImpl, data);
    }

    function configCall(ReleaseProxy proxy, bytes memory data) public payable virtual onlyOwner {
        proxy.configCall(data);
    }

}