// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title MRTNFToken
/// @author Mathieu Ridet
/// @notice ERC721 NFT token with minting, royalties, and cooldown protection
/// @dev Implements sequential token ID minting with a minting cooldown period per address
contract MRTNFToken is ERC721Royalty, Ownable, ReentrancyGuard, Pausable {
    /// @notice Minimum time between mints for a single address
    uint256 public constant MINT_INTERVAL = 1 hours;

    /// @notice Error thrown when max supply is set to zero
    error MRTNFToken__MaxSupplyZero();
    
    /// @notice Error thrown when base URI is empty
    error MRTNFToken__BaseURIEmpty();
    
    /// @notice Error thrown when royalty receiver address is zero
    error MRTNFToken__RoyaltyReceiverZero();
    
    /// @notice Error thrown when royalty basis points is zero
    error MRTNFToken__RoyaltyBpsZero();
    
    /// @notice Error thrown when mint quantity is zero
    error MRTNFToken__QTYZero();
    
    /// @notice Error thrown when minting would exceed max supply
    error MRTNFToken__MaxSupplyExceeded();
    
    /// @notice Error thrown when insufficient ETH is sent for minting
    error MRTNFToken__InsufficientETH();
    
    /// @notice Error thrown when minting is attempted before cooldown period expires
    error MRTNFToken__MintTooSoon();
    
    /// @notice Error thrown when withdrawal fails
    error MRTNFToken__WithdrawFailed();

    /// @notice Maximum number of NFTs that can be minted
    uint256 public immutable MAX_SUPPLY;

    /// @notice Price per NFT in wei
    uint256 public immutable MINT_PRICE;

    /// @notice Base URI for token metadata (e.g., "ipfs://QmCID/")
    string private baseTokenURI;

    /// @notice Mapping of address to last mint timestamp
    mapping(address => uint256) public lastMint;

    /// @notice Next available token ID (starts at 1)
    uint256 private nextAvailableTokenId = 1;

    /// @notice Constructs the MRTNFToken contract
    /// @param initialOwner Address that will own the contract
    /// @param baseURI Base URI for token metadata
    /// @param maxSupply Maximum number of NFTs that can be minted
    /// @param mintPriceWei Price per NFT in wei
    /// @param royaltyReceiver Address that will receive royalty payments
    /// @param royaltyBps Royalty amount in basis points (1 basis point = 0.01%)
    constructor(
        address initialOwner,
        string memory baseURI,
        uint256 maxSupply,
        uint256 mintPriceWei,
        address royaltyReceiver,
        uint96 royaltyBps
    ) ERC721("MRTNFToken", "MRTNFT") Ownable(initialOwner) {
        require(maxSupply > 0, MRTNFToken__MaxSupplyZero());
        require(bytes(baseURI).length > 0, MRTNFToken__BaseURIEmpty());
        require(royaltyReceiver != address(0), MRTNFToken__RoyaltyReceiverZero());
        require(royaltyBps > 0, MRTNFToken__RoyaltyBpsZero());

        MAX_SUPPLY = maxSupply;
        MINT_PRICE = mintPriceWei;
        baseTokenURI = baseURI;

        _setDefaultRoyalty(royaltyReceiver, royaltyBps);
    }

    /// @notice Allows a user to mint one or more NFTs
    /// @dev Requires payment, respects cooldown period, and enforces max supply
    /// @param quantity Number of NFTs to mint
    /// @dev Refunds excess ETH if more than required is sent
    function mint(uint256 quantity) external payable whenNotPaused nonReentrant {
        require(quantity > 0, MRTNFToken__QTYZero());
        require(totalSupply() + quantity <= MAX_SUPPLY, MRTNFToken__MaxSupplyExceeded());

        uint256 cost = MINT_PRICE * quantity;
        require(msg.value >= cost, MRTNFToken__InsufficientETH());

        // enforce cooldown
        require(block.timestamp >= lastMint[msg.sender] + MINT_INTERVAL, MRTNFToken__MintTooSoon());

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = nextAvailableTokenId;
            nextAvailableTokenId = nextAvailableTokenId + 1;
            _safeMint(msg.sender, tokenId);
        }

        // update last mint timestamp for this wallet
        lastMint[msg.sender] = block.timestamp;

        uint256 refund = msg.value - cost;
        if (refund > 0) {
            (bool ok,) = msg.sender.call{value: refund}("");
            if (!ok) {
                // refund failed — do NOT revert
                // the extra ETH remains in this contract; owner can withdraw later
            }
        }
    }

    /// @notice Updates the base URI for token metadata
    /// @param newBaseURI New base URI string
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseTokenURI = newBaseURI;
    }

    /// @notice Sets the default royalty information
    /// @param receiver Address that will receive royalty payments
    /// @param bps Royalty amount in basis points (1 basis point = 0.01%)
    function setDefaultRoyalty(address receiver, uint96 bps) external onlyOwner {
        _setDefaultRoyalty(receiver, bps);
    }

    /// @notice Deletes the default royalty information
    function deleteDefaultRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }

    /// @notice Withdraws all ETH from the contract to the specified address
    /// @param to Address to receive the withdrawn ETH
    function withdraw(address payable to) external onlyOwner {
        (bool ok,) = to.call{value: address(this).balance, gas: 30000}("");
        require(ok, MRTNFToken__WithdrawFailed());
    }

    /// @notice Pauses or unpauses minting
    /// @param active True to enable minting, false to pause
    function setSaleActive(bool active) external onlyOwner {
        active ? _unpause() : _pause();
    }

    /// @notice Returns the total number of tokens minted
    /// @return Total supply of tokens
    function totalSupply() public view returns (uint256) {
        return nextAvailableTokenId - 1;
    }

    /// @notice Returns the base URI for token metadata
    /// @return Base URI string
    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    /// @notice Returns the URI for a given token ID, appending ".json" to the base URI
    /// @param tokenId Token ID to query
    /// @return Full URI string with ".json" extension
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return string.concat(super.tokenURI(tokenId), ".json");
    }

    /// @notice Checks if the contract supports a given interface
    /// @param interfaceId Interface ID to check
    /// @return True if the interface is supported
    function supportsInterface(bytes4 interfaceId) public view override(ERC721Royalty) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
