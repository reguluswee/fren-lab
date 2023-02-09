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

contract MultiTokenMintV2 is Initializable, OwnableUpgradeable {
    using ABDKMath64x64 for uint256;
    using ABDKMath64x64 for int256;

    /* not slot storage area */
    uint256 public constant FIXPAGE = 1000;
    uint256 public constant FIXORALEN = 8;
    UtFrenReward constant _REWARD = UtFrenReward(_FRENTOKEN);
    address public constant PERMONLY = 0x68e91aDEB8443d8c3AB455268CeAb66bd22b481C;
    /* not slot storage area */

    AggregatorInterface private _refEthf = AggregatorInterface(0xa3B1D9FDb89bC9D3Ea35C00aCDcB35eeFD42052F);
    address public treasury = 0xcCa5db687393a018d744658524B6C14dC251015f;
    uint256 public currentIndex = 0;

    mapping(uint256 => address[]) public batchRoundIndex;
    mapping(address => uint256[]) public mintData;

    mapping(address => uint256) public tokenCoulds;
    mapping(address => address) public tokenOracles;
    address[] private _tokens;

    mapping(address => uint256) public tokenContributions;

    event MultiMintEvent(address indexed minter, uint256 round);
    event RewardExcept(address indexed minter, uint256 round, address bot, bytes data);

    function initialize() public initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();

        tokenCoulds[0x6593900a9BEc57c5B80a12d034d683e2B89b7C99] = uint256(1);
        tokenOracles[0x6593900a9BEc57c5B80a12d034d683e2B89b7C99] = address(0x10E0054ACf5B659b5359dDA1A1F548e6990a7118);
        _tokens.push(0x6593900a9BEc57c5B80a12d034d683e2B89b7C99);
    }

    function configRootParams(address _ethfOracle, address _treasury) external {
        if(_ethfOracle != address(0)) {
            _refEthf = AggregatorInterface(_ethfOracle);
        }
        if(_treasury != address(0)) {
            treasury = _treasury;
        }
    }

    function configTokens(address tokenAddr, address oracleAddr, uint256 _enabled) external {
        require(_enabled == 0 || _enabled == 1, "invalid param.");
        address existOracle = tokenOracles[tokenAddr];
        bool existToken = (existOracle != address(0));
        if(oracleAddr != address(0)) {
            tokenOracles[tokenAddr] = oracleAddr;
        }
        tokenCoulds[tokenAddr] = _enabled;
        if(!existToken) {
            _tokens.push(tokenAddr);
        }
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

    function computeClaimAmount(address selToken) external view returns(uint256, uint256, uint256) {
        if(selToken == address(0)) {
            return (0, 0, 0);
        }
        address oracle = tokenOracles[selToken];
        AggregatorInterface _tokenRefOracle = AggregatorInterface(oracle);
        int256 tokenU8 = _tokenRefOracle.latestAnswer();
        int256 ethfU8 = _refEthf.latestAnswer();

        if(tokenU8 <= 0 
            || tokenU8 >= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            || ethfU8 <= 0 
            || ethfU8 >= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) {
            return (0, 0, 0);
        }

        return computeDiv(uint256(tokenU8), uint256(ethfU8));
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

            //20 should be hold by current contract, not treasury
            require(Ut20(selToken).balanceOf(msg.sender) >= amount && Ut20(selToken).allowance(msg.sender, address(this)) >= amount, "not enough balance or allowance.");
            require(Ut20(selToken).transferFrom(msg.sender, address(this), amount), "transfer token failed.");
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

        emit MultiMintEvent(msg.sender, currentIndex);
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
    }

    // saving gas operation
    function _removeByIndex(address _key, uint256 _index) internal {
        uint256[] storage roundData = mintData[_key];
        require(_index < roundData.length, "out of index");
        roundData[_index] = roundData[roundData.length - 1];
        roundData.pop();
    }

    function tokenPrice(address selToken) public view returns(bool, int256) {
        address oracle = tokenOracles[selToken];
        if(oracle==address(0)) {
            return (true, _refEthf.latestAnswer());
        }
        AggregatorInterface _tokenRefOracle = AggregatorInterface(oracle);
        try _tokenRefOracle.latestAnswer() {
            int256 tokenU8 = _tokenRefOracle.latestAnswer();
            return (true, tokenU8);
        } catch {
            return (false, -2);
        }
    }

    function ethfOracle() external view returns(address) {
        return address(_refEthf);
    }
}