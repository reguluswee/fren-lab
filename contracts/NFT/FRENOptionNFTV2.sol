// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../Math.sol";
import "./IMinter.sol";
import "./IBurnableFOPV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/*
 @dev this contract should overload self logicial for outside compute, fren batch mint tool is facade of this contract
 */
contract FRENOptionNFTV2 is IERC721, ERC165, IERC721Metadata, Ownable, IMinter, IBurnableFOPV2 {
    using Address for address;
    using Strings for uint256;

    address private _minter;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // The next token ID to be minted.
    uint256 private _currentIndex;

    // The number of tokens burned.
    uint256 private _burnCounter;

    // Mapping from token ID to owner address
    // mapping(uint256 => address) private _owners;
    mapping(uint256 => BullPack) private _owners;   //core data objects

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    string private _baseTokenURI = "";

    // constructor(string memory name_, string memory symbol_) {
    //     _name = name_;
    //     _symbol = symbol_;
    // }
    constructor(address _initialMinter) {
        _name = "FREN Option Rights V2";
        _symbol = "FOPV2";
        _currentIndex = 0;
        _minter = _initialMinter;
    }

    function setBaseURI(string memory wrapperUri) external onlyOwner {
        _baseTokenURI = wrapperUri;
    }

    function getBaseURI() public view returns (string memory) {
        return _baseTokenURI;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = getBaseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        // address owner = _owners[tokenId];
        // require(owner != address(0), "ERC721: invalid token ID");
        // return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
        BullPack memory ownerPack = _owners[tokenId];
        require(ownerPack.minter != address(0), "ERC721: invalid tokenID");
        return (spender == ownerPack.minter || isApprovedForAll(ownerPack.minter, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual returns (address) {
        _requireMinted(tokenId);

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev Reverts if the `tokenId` has not been minted yet.
     */
    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "ERC721: invalid token ID");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId].minter != address(0);
    }

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) public view returns (uint256 balance) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId].minter;
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
        _safeTransfer(from, to, tokenId, "");
    }

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not token owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }


    error MintZeroQuantity();

    function totalIndex() public view virtual returns (uint256) {
        return _currentIndex;
    }

    function totalBurned() public view virtual returns (uint256) {
        return _burnCounter;
    }

    /************** custom ERC721 method **************/
    function totalSupply() public view virtual returns (uint256) {
        unchecked {
            return _currentIndex - _burnCounter;
        }
    }

    function ownerOfWithPack(uint256 tokenId) public view returns (bool, BullPack memory) {
        BullPack memory pack = _owners[tokenId];
        if(pack.minter==address(0)) {
            return (false, pack);
        }
        //require(pack.minter != address(0), "ERC721: invalid token ID");   // for query side
        // return (pack);
        return (true, pack);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;

        _owners[tokenId].minter = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    function transferMinter(address newMinter) external override onlyOwner {
        require(newMinter != address(0), "Mintable: new minter is the zero address");
        address oldMinter = _minter;
        _minter = newMinter;
        emit MintershipTransferred(oldMinter, newMinter);
    }

    modifier onlyMinter() {
        _checkMinter();
        _;
    }

    function _checkMinter() internal view virtual {
        require(minter() == _msgSender(), "Mintable: caller is not the allowed minter");
    }

    function minter() public view virtual returns (address) {
        return _minter;
    }

    function mintOption(address giveAddress, uint256 eaaRate, uint256 amp, uint256 cRank, uint256 term, uint256 maturityTs, uint256 canTransfer,
        address[] calldata pMinters) 
        external onlyMinter returns(uint256 _newTokenId){
        require(giveAddress != address(0), "ERC721: address zero is not a valid owner");
        //require(_balances[giveAddress] == 0, "minting is existing");

        uint256 tokenId = ++_currentIndex;
        _mint(giveAddress, tokenId, eaaRate, amp, cRank, term, maturityTs, canTransfer, pMinters);
        emit OpMint(giveAddress, tokenId, _currentIndex);
        return tokenId;
    }

    // minter admin manage all
    function burnOption(uint256 tokenId) external onlyMinter {
        // require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");

        address owner = FRENOptionNFTV2.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        _burnCounter++;

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);

        emit OpBurn(owner, tokenId);
    }

    function _mint(address to, uint256 _tokenId, uint256 _eaaRate, uint256 _amp, uint256 _cRank, uint256 _term, uint256 _maturityTs, uint256 _canTransfer,
        address[] calldata pMinters) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(_tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, _tokenId);
        BullPack memory bp = BullPack({
            minter: to,
            tokenId: _tokenId,
            eaaRate: _eaaRate,
            amp: _amp,
            cRank: _cRank,
            term: _term,
            maturityTs: _maturityTs,
            canTransfer: _canTransfer,
            pMinters: pMinters
        });

        _balances[to] += 1;
        _owners[_tokenId] = bp;

        emit Transfer(address(0), to, _tokenId);

        _afterTokenTransfer(address(0), to, _tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        if(from == address(0) || to == address(0)) {
            //mint or burn
            return;
        }
        require(from != to, "could not transfer to self.");
        // check token wether could be transfer
        (bool result, BullPack memory pack) = ownerOfWithPack(tokenId);
        require(result, "non exist token id.");
        require(pack.canTransfer == 1, "this token could not be transfered.");
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}