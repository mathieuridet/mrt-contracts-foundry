// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20CappedUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {UUPSProxy} from "src/UUPSProxy.sol";
import {CodeConstants} from "utils/CodeConstants.sol";

/// @title MRToken V2 (just for upgrade testing)
/// @author Mathieu Ridet
/// @notice ERC20 token with permit functionality, capped supply, and owner minting
/// @dev Maximum supply is capped at 1,000,000 tokens
contract MRTokenV2 is ERC20Upgradeable, ERC20CappedUpgradeable, ERC20PermitUpgradeable, OwnableUpgradeable, UUPSUpgradeable, CodeConstants {
    // Storage variables
    uint8 public s_addStorageVarTest;

    /// @notice Useful to add state variables in new versions of the contract
    uint256[49] private __gap;

    // Functions
    /// @notice Constructs the MRToken contract
    /// @dev Mints 1000 tokens to the deployer on initialization
    function initializeV2() public reinitializer(2) {
        s_addStorageVarTest = 4;
        _mint(msg.sender, INITIAL_MINT);
    }

    function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}

    /// @notice Mints new tokens to the specified address
    /// @param _to Address to receive the minted tokens
    /// @param _amount Amount of tokens to mint
    /// @dev Only the owner can mint, and minting must not exceed the cap
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    /// @notice Updates token balances and enforces the cap
    /// @param from Address tokens are transferred from
    /// @param to Address tokens are transferred to
    /// @param value Amount of tokens to transfer
    /// @dev Overrides both ERC20Upgradeable and ERC20CappedUpgradeable _update functions
    function _update(address from, address to, uint256 value) internal override(ERC20Upgradeable, ERC20CappedUpgradeable) {
        super._update(from, to, value);
    }

    function version() external pure returns (uint256) {
        return 2;
    }
}
