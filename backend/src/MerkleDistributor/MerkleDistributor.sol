// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title MerkleDistributor
/// @author Mathieu Ridet
/// @notice One-time token claims for an allowlist using a Merkle root
contract MerkleDistributor is Ownable {
    /// @notice ERC20 token being distributed
    IERC20 public immutable TOKEN;

    /// @notice Fixed reward amount per claim
    uint256 public immutable REWARD_AMOUNT;

    /// @notice Current Merkle root for claim verification
    bytes32 public merkleRoot;

    /// @notice Current distribution round
    uint64 public round;

    /// @notice Error thrown when root is set to zero
    error MerkleDistributor__RootZero();

    /// @notice Error thrown when attempting to set a round backwards
    error MerkleDistributor__RoundBackwards();

    /// @notice Error thrown when claim amount doesn't match REWARD_AMOUNT
    error MerkleDistributor__WrongAmount();

    /// @notice Error thrown when address has already claimed for this round
    error MerkleDistributor__AlreadyClaimed();

    /// @notice Error thrown when claiming for wrong round
    error MerkleDistributor__WrongRound();

    /// @notice Error thrown when Merkle proof verification fails
    error MerkleDistributor__BadProof();

    /// @notice Error thrown when token transfer fails
    error MerkleDistributor__TransferFailed();

    /// @notice Mapping of round => address => claimed status
    mapping(uint64 => mapping(address => bool)) private claimed;

    /// @notice Emitted when a new root and round are set
    /// @param newRoot New Merkle root
    /// @param newRound New round number
    event RootUpdated(bytes32 indexed newRoot, uint64 indexed newRound);

    /// @notice Emitted when a claim is successful
    /// @param round Round number of the claim
    /// @param account Address that claimed
    /// @param amount Amount claimed
    event Claimed(uint64 indexed round, address indexed account, uint256 amount);

    /// @notice Constructs the MerkleDistributor contract
    /// @param initialOwner Address that will own the contract
    /// @param _token ERC20 token to distribute
    /// @param _rewardAmount Fixed reward amount per claim
    constructor(address initialOwner, IERC20 _token, uint256 _rewardAmount) Ownable(initialOwner) {
        TOKEN = _token;
        REWARD_AMOUNT = _rewardAmount;
    }

    /// @notice Sets a new Merkle root and round for claims
    /// @param newRoot New Merkle root for claim verification
    /// @param newRound New round number (must be >= current round)
    /// @dev Allows updating multiple times within the same round
    function setRoot(bytes32 newRoot, uint64 newRound) external onlyOwner {
        require(newRoot != bytes32(0), MerkleDistributor__RootZero());
        require(newRound >= round, MerkleDistributor__RoundBackwards());
        merkleRoot = newRoot;
        round = newRound;
        emit RootUpdated(newRoot, newRound);
    }

    /// @notice Checks if an address has claimed for a specific round
    /// @param r Round number to check
    /// @param a Address to check
    /// @return True if the address has claimed for this round
    function isClaimed(uint64 r, address a) public view returns (bool) {
        return claimed[r][a];
    }

    /// @notice Claims tokens for an address using a Merkle proof
    /// @param r Round number to claim for
    /// @param account Address claiming the reward
    /// @param amount Amount to claim (must equal REWARD_AMOUNT)
    /// @param merkleProof Merkle proof to verify the claim
    /// @dev Can only claim once per round per address
    function claim(uint64 r, address account, uint256 amount, bytes32[] calldata merkleProof) external {
        require(r == round, MerkleDistributor__WrongRound());
        require(amount == REWARD_AMOUNT, MerkleDistributor__WrongAmount());
        require(!claimed[r][account], MerkleDistributor__AlreadyClaimed());

        bytes32 leaf = keccak256(abi.encodePacked(account, amount, r));
        require(MerkleProof.verify(merkleProof, merkleRoot, leaf), MerkleDistributor__BadProof());

        claimed[r][account] = true;
        require(TOKEN.transfer(account, amount), MerkleDistributor__TransferFailed());
        emit Claimed(r, account, amount);
    }

    /// @notice Owner can rescue leftover tokens after the claim window
    /// @param to Address to receive the rescued tokens
    /// @param amount Amount of tokens to rescue
    function rescue(address to, uint256 amount) external onlyOwner {
        require(TOKEN.transfer(to, amount), MerkleDistributor__TransferFailed());
    }
}
