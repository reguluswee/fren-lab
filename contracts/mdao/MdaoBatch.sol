pragma solidity 0.8.17;

interface IXEN{
    function claimRank(uint256 term) payable external;
    function claimMintRewardAndShare(address other,uint256 pct) external;
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IXEN2{
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract PROXY{
    IXEN private constant xen = IXEN(0x7127deeff734cE589beaD9C4edEFFc39C9128771);
    address owner;

    constructor() payable {
        xen.approve(msg.sender, ~uint256(0));
        owner = tx.origin;
    }

    function mint(uint256 term) public {
        xen.claimRank{value: 1 ether}(term);
    }

    function claim() public {
        require(tx.origin == owner);
        xen.claimMintRewardAndShare(tx.origin, 95);
        selfdestruct(payable(tx.origin));
    }
}

contract XEN {
    IXEN2 private constant xen = IXEN2(0x7127deeff734cE589beaD9C4edEFFc39C9128771);
    mapping (address => bool) public whiteList;
    mapping (address => mapping (uint256 => address[])) public userContracts;
    mapping (address => mapping (uint256 => uint256)) public userTermLength;
    address public owner;
    address public memoryLabs;
    bool public needWhite;

    constructor() {
        owner = msg.sender;
        memoryLabs = msg.sender;
        whiteList[msg.sender] = true;
    }

    function setNeedWhite(bool need) public {
        require(msg.sender == owner);
        needWhite = need;
    }

    function setLabsWallet(address newWallet) public {
        require(msg.sender == owner);
        memoryLabs = newWallet;
    }

    function setWhiteList(address user, bool isWhite) public {
        require(msg.sender == owner);
        whiteList[user] = isWhite;
    }

    function mint(uint256 amount, uint256 term) public payable {
        if (needWhite) {
            require(whiteList[msg.sender]);
        }
        address user = msg.sender;
        require(msg.value == amount * 1 ether);
        for(uint256 i; i < amount; i++){
            PROXY proxy = new PROXY{value: 1 ether}();
            proxy.mint(term);
            userContracts[user][term].push(address(proxy));
            userTermLength[user][term]++;
        }
    }

    function claim(uint256 amount, uint256 term) public {
        if (needWhite) {
            require(whiteList[msg.sender]);
        }
        address user = msg.sender;
        for(uint256 i; i < amount; i++){
            uint256 count = userContracts[user][term].length;
            address proxy = userContracts[user][term][count - 1];
            PROXY(proxy).claim();
            xen.transferFrom(proxy, memoryLabs, xen.balanceOf(proxy));
            userContracts[user][term].pop();
            userTermLength[user][term]--;
        }
    }
}