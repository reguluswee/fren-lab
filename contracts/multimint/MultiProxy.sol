// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MultiProxy is ERC1967Proxy {

    bytes public constant MULTI_ADMIN = "eip1967.proxy.admin";

    constructor(address _logic, bytes memory _data) payable ERC1967Proxy(_logic, _data) {
        assert(_ADMIN_SLOT == bytes32(uint256(keccak256(MULTI_ADMIN)) - 1));
        uint256 deploysize;
        address deployer = msg.sender;
        assembly {
            deploysize := extcodesize(deployer)
        }
        assert(deploysize==0);
        _changeAdmin(msg.sender);
    }

    modifier ifAdmin() {
        if(msg.sender == _getAdmin()) {
            _;
        } else {
            _fallback();
        }
    }

    function admin() external ifAdmin returns (address) {
        return _getAdmin();
    }

    function implementation() external ifAdmin returns (address) {
        return _implementation();
    }

    function changeAdmin(address _newAdmin) external virtual ifAdmin {
        _changeAdmin(_newAdmin);
    }

    function upgradeTo(address _newImpl) external ifAdmin {
        _upgradeToAndCall(_newImpl, "", false);
    }

    function upgradeToAndCall(address _newImpl, bytes calldata data) external payable ifAdmin {
        _upgradeToAndCall(_newImpl, data, true);
    }

    function withdraw() external ifAdmin {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function _beforeFallback() internal virtual override {
        require(msg.sender != _getAdmin(), "admin should not to proxy-call target function");
        super._beforeFallback();
    }

    receive() external payable virtual override {
    }
}