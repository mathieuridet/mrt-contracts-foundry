// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title MRToken
/// @author Mathieu Ridet
/// @notice ERC20 token with permit functionality, capped supply, and owner minting
/// @dev Maximum supply is capped at 1,000,000 tokens
contract MRToken is ERC20, Ownable, ERC20Permit, ERC20Capped {
    /// @notice Constructs the MRToken contract
    /// @param initialOwner Address that will own the contract and can mint tokens
    /// @dev Mints 1000 tokens to the deployer on initialization
    constructor(address initialOwner)
        ERC20("MRToken", "MRT")
        ERC20Permit("MRToken")
        Ownable(initialOwner)
        ERC20Capped(1_000_000 * 10 ** 18)
    {
        _mint(msg.sender, 1000 * 10 ** 18);
    }

    /// @notice Updates token balances and enforces the cap
    /// @param from Address tokens are transferred from
    /// @param to Address tokens are transferred to
    /// @param value Amount of tokens to transfer
    /// @dev Overrides both ERC20 and ERC20Capped _update functions
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Capped) {
        super._update(from, to, value);
    }

    /// @notice Mints new tokens to the specified address
    /// @param _to Address to receive the minted tokens
    /// @param _amount Amount of tokens to mint
    /// @dev Only the owner can mint, and minting must not exceed the cap
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}
