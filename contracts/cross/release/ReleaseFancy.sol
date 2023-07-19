// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface CrossToken {
    function crossIn(bytes32 _merkleRoot, uint256 _amount) external;
}

contract ReleaseFancy is Initializable, OwnableUpgradeable {

    mapping(bytes32 => uint256) public roundMapping;

    event ReleaseRound(bytes32 indexed roundRoot, uint256 amount);

    function initialize() public initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }
    
    function crossRound(address _token, bytes32 _merkleRoot, uint256 _amount) external onlyOwner{
        require(roundMapping[_merkleRoot] == 0, "already set");

        CrossToken ct = CrossToken(_token);
        roundMapping[_merkleRoot] = _amount;
        ct.crossIn(_merkleRoot, _amount);

        emit ReleaseRound(_merkleRoot, _amount);
    }
}