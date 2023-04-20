// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../../common/Utility.sol";

contract GeneralBatch is Initializable, OwnableUpgradeable, BatchCop {
    using ABDKMath64x64 for uint256;

    UtFrenReward constant _REWARD = UtFrenReward(_FRENTOKEN);
    Ut20 constant _FREN = Ut20(_FRENTOKEN);

    uint256 public currentIndex = 0;

    mapping(uint256 => address[]) public batchRoundIndex;
    mapping(address => uint256[]) public mintData;

    event RewardExcept(address indexed minter, uint256 round, address bot, bytes data);

    function initialize() public initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function getMintingLen(address minter) view public returns(uint256) {
        uint256[] storage data = mintData[minter];
        return data.length;
    }

    function getMintingData(address minter) view public returns(uint256[] memory) {
        return mintData[minter];
    }

    function getRoundBots(uint256 round) view public returns(address[] memory) {
        return batchRoundIndex[round];
    }

    function claimRank(uint256 times, uint256 term) external payable {
        require(times > 0 && term > 0, "invalid batch parameters");
        require(msg.value == times * _FREN.timePrice(), "batch mint value not correct.");

        uint256 size;
        address sender = msg.sender;
        assembly {
            size := extcodesize(sender)
        }
        require(size == 0, "only EOA allowed.");

        uint256 singlePay = msg.value / times;

        address[] memory proBots = new address[](times);

        for(uint256 i; i<times; i++){
            UtMinter get = new UtMinter();
            (bool exeResult, ) = address(get).call{value:singlePay}(abi.encodeWithSignature("claimRank(uint256)", term));
            
            if(!exeResult) {
                // stop and revert all transaction
                revert(string(abi.encodePacked("FREN token claim Error.", Strings.toString(i))));
            }
            proBots[i] = address(get);
        }
        batchRoundIndex[++currentIndex] = proBots;
        mintData[msg.sender].push(currentIndex);

        emit BatchClaim(msg.sender, times, term, _FREN.timePrice());
    }

    function claimMintReward(uint256 index) external {
        require(index > 0, "invalid index id.");
        uint256[] storage roundData = mintData[msg.sender];

        require(roundData.length > 0, "empty minting data.");
        
        uint256 storedRound = 0;
        uint256 storedArrayIndex = 0;
        for(uint256 i; i<roundData.length; i++) {
            if(index==roundData[i]) {
                storedRound = index;
                storedArrayIndex = i;
            }
        }
        require(storedRound > 0, "empty rounding data.");

        address[] storage getter = batchRoundIndex[storedRound];
        require(getter.length > 0, "Fren Mint Bots empty.");

        for(uint256 i; i<getter.length; i++) {
            address get = getter[i];
            (bool ok, bytes memory data) = address(get).call(abi.encodeWithSignature("claimMintReward()"));
            if(!ok) {
                emit RewardExcept(msg.sender, storedRound, get, data);
            }
            uint256 balance = _REWARD.balanceOf(get);

            if(balance > 0) {
                _REWARD.transferFrom(get, msg.sender, balance);
            }
        }
        delete batchRoundIndex[storedRound];
        //delete mintData[msg.sender][storedArrayIndex]; //replace with belowed method call
        _removeByIndex(msg.sender, storedArrayIndex);

        emit BatchReward(msg.sender, index);
    }

    // saving gas operation
    function _removeByIndex(address _key, uint256 _index) internal {
        uint256[] storage roundData = mintData[_key];
        require(_index < roundData.length, "out of index");
        roundData[_index] = roundData[roundData.length - 1];
        roundData.pop();
    }
}