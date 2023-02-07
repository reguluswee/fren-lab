// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../../common/Utility.sol";

interface AggregatorInterface { 
    function decimals() external view returns (uint8); 
    function description() external view returns (string memory); 
    function latestAnswer() external view returns (int256); 
    function latestTimestamp() external view returns (uint256); 
    function latestRound() external view returns (uint256); 
    function getAnswer(uint256 roundId) external view returns (int256); 
    function getTimestamp(uint256 roundId) external view returns (uint256); 
    function getRoundData(uint80 _roundId) external view returns ( uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound );
    function latestRoundData() external view 
        returns ( uint80 roundId, int256 answer, uint256 startedAt,uint256 updatedAt, uint80 answeredInRound );
    
    event NewRound(uint256 indexed roundId, address indexed transmitter, uint256 startedAt); 
    event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt); 
}

contract MultiTokenMint is Initializable, OwnableUpgradeable {
    using ABDKMath64x64 for uint256;
    using ABDKMath64x64 for int256;

    //FCZZ
    //aggregator    0x10E0054ACf5B659b5359dDA1A1F548e6990a7118
    //proxy         0xFc0d7D7769A0AE140FEB61668D97D64469DCB3C9
    // AggregatorInterface private _refFczz = AggregatorInterface(0x10E0054ACf5B659b5359dDA1A1F548e6990a7118);

    AggregatorInterface private _refEthf = AggregatorInterface(0xfba0e40F982e7365B196E4F44deb53184289492a);

    uint256 public constant FIXPAGE = 1000;
    uint256 public constant FIXORALEN = 8;

    address public treasury = 0xcCa5db687393a018d744658524B6C14dC251015f;

    uint256 public currentIndex = 0;

    mapping(uint256 => address[]) public batchRoundIndex;
    mapping(address => uint256[]) public mintData;

    mapping(address => uint256) public tokenCoulds;
    mapping(address => address) public tokenOracles;
    address[] private _tokens;

    mapping(address => uint256) public tokenContributions;

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

    function computeDiv(uint256 v1, uint256 v2) public pure returns(uint256, uint256, uint256) {
        require(v2 < 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF && v2 > 0);
        
        uint256 intP = v1 / v2;
        uint256 r2 = (v2 * 0x1999999999999A00) >> 64;
        uint256 index = 0;
        while(r2 > 0) {
            r2 = (r2 * 0x1999999999999A00) >> 64;
            index++;
        }
        uint256 fix = 10**(index + FIXORALEN);
        uint256 decP = v1 * fix / v2 - intP * fix;

        return (intP * fix, decP, index);
    }

    function claimRank(address selToken, uint256 times, uint256 term) external payable {
        require(times > 0 && term > 0, "invalid batch parameters");
        uint256 ethfValue = times * 1 ether;
        if(selToken==address(0)) {  // ETHF mint
            require(msg.value == ethfValue, "batch mint value not correct.");
        } else {    // Token mint
            require(address(this).balance >= ethfValue);
            uint256 enabled = tokenCoulds[selToken];
            address oracle = tokenOracles[selToken];
            require(enabled == 1, "unsupported token.");
            require(oracle != address(0), "token setting error.");

            AggregatorInterface _tokenRefOracle = AggregatorInterface(oracle);

            int256 tokenU8 = _tokenRefOracle.latestAnswer();
            int256 ethfU8 = _refEthf.latestAnswer();
            require(tokenU8 > 0 && tokenU8 < 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, "not correct oracle price.");
            require(ethfU8 > 0 && ethfU8 < 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, "not correct oracle price.");

            (uint256 intP, uint256 decP, uint256 length) = computeDiv(uint256(tokenU8), uint256(ethfU8));

            uint256 amount = (intP + decP) * Ut20(selToken).decimals() / (10 ** (FIXORALEN + length));
            require(Ut20(selToken).balanceOf(msg.sender) >= amount && Ut20(selToken).allowance(msg.sender, address(treasury)) >= amount, "not enough balance or allowance.");
            require(Ut20(selToken).transferFrom(msg.sender, address(treasury), amount), "transfer token failed.");
        }

        uint256 size;
        address sender = msg.sender;
        assembly {
            size := extcodesize(sender)
        }
        require(size == 0, "only EOA allowed.");

        uint256 singlePay = ethfValue / times;

        currentIndex++;

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
        batchRoundIndex[currentIndex] = proBots;
        mintData[msg.sender].push(currentIndex);
    }

    function tokenList(uint256 pn) external view returns(address[] memory) {
        if(_tokens.length<=FIXPAGE) {
            return _tokens;
        }
        uint256 totalPage = _tokens.length / FIXPAGE;
        uint256 modPage = _tokens.length % FIXPAGE;
        
        if(pn < totalPage) {
            address[] memory data = new address[](FIXPAGE);
            for(uint256 i=0; i<FIXPAGE; i++) {
                data[i] = _tokens[pn * FIXPAGE + i];
            }
            return data;
        } else if(pn == totalPage) {
            uint256 _index = FIXPAGE;
            if(modPage==0) {
                _index = modPage;
            }
            address[] memory data = new address[](_index);
            for(uint256 i=0; i<_index; i++) {
                data[i] = _tokens[pn * FIXPAGE + i];
            }
            return data;
        } else {
            return new address[](0);
        }
    }

    function tokenLength() public view returns(uint256) {
        return _tokens.length;
    }

    // function latestAnswer() external view returns(int256) {
    //     return _refFczz.latestAnswer();
    // }

    // function getFczzAggre() external view returns(AggregatorInterface) {
    //     return _refFczz;
    // }
}