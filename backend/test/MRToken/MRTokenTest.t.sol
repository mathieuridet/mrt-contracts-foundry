// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MRTokenV1} from "src/MRToken/MRTokenV1.sol";
import {CodeConstants} from "utils/CodeConstants.sol";
import {UUPSProxy} from "src/UUPSProxy.sol";

contract MRTokenTest is Test, CodeConstants {
    UUPSProxy public proxy;
    address public proxyAddress;
    address public owner;
    MRTokenV1 instance;

    function setUp() public {
        owner = address(this);
        bytes memory initData = abi.encodeCall(MRTokenV1.initialize, (owner));
        proxy = new UUPSProxy(address(new MRTokenV1()), initData);
        proxyAddress = address(proxy);

        instance = MRTokenV1(proxyAddress);
    }

    function test_initialDeployment() public view {
        // Assert that the token name is correct
        assertEq(instance.name(), "MRToken", "Token name should be MRToken");

        // Assert that the token symbol is correct
        assertEq(instance.symbol(), "MRT", "Token symbol should be MRT");

        // Assert that the initial supply is minted to the deployer
        assertEq(instance.balanceOf(address(this)), INITIAL_MINT, "Initial supply should be 1000 tokens");
    }

    function test_mint() public {
        // Mint 100 tokens to a specific address
        address recipient = address(0x123);
        instance.mint(recipient, 100 * 10 ** 18);

        // Assert that the recipient's balance is updated
        assertEq(instance.balanceOf(recipient), 100 * 10 ** 18, "Recipient should have 100 tokens");

        // Assert that the total supply is updated
        assertEq(instance.totalSupply(), 1100 * 10 ** 18, "Total supply should be 1100 tokens");
    }

    function test_mintBeyondCap() public {
        // Try to mint tokens that exceed the cap
        uint256 amount = CAP; // Cap is 1,000,000 tokens
        vm.expectRevert();
        instance.mint(address(this), amount + 1);
    }

    function test_onlyOwnerCanMint() public {
        // Change the owner to another address
        address nonOwner = address(0x456);

        // Try to mint tokens from a non-owner account
        vm.prank(nonOwner);
        vm.expectRevert();
        instance.mint(nonOwner, 100 * 10 ** 18);
    }

    function test_transferInsufficientBalance() public {
        // Try to transfer more tokens than the sender has
        address recipient = address(0x123);
        vm.expectRevert();
        bool result = instance.transfer(recipient, 2000 * 10 ** 18); // Sender only has 1000 tokens

        // Assert that the transfer was not done
        assertEq(result, false);
    }

    function test_transferOwnership() public {
        // Transfer ownership to a new address
        address newOwner = address(0x789);
        instance.transferOwnership(newOwner);

        // Assert that the new owner is set
        assertEq(instance.owner(), newOwner, "New owner should be set");

        // Try to mint tokens as the old owner
        vm.expectRevert();
        instance.mint(address(this), 100 * 10 ** 18);

        // Mint tokens as the new owner
        vm.prank(newOwner);
        instance.mint(newOwner, 100 * 10 ** 18);

        // Assert that the new owner's balance is updated
        assertEq(instance.balanceOf(newOwner), 100 * 10 ** 18, "New owner should have 100 tokens");
    }

    function test_transfer() public {
        // Transfer 100 tokens to another address
        address recipient = address(0x123);
        bool result = instance.transfer(recipient, 100 * 10 ** 18);

        // Assert that the transfer was done successfully
        assertEq(result, true);

        // Assert that the sender's balance is reduced
        assertEq(instance.balanceOf(address(this)), 900 * 10 ** 18, "Sender should have 900 tokens");

        // Assert that the recipient's balance is increased
        assertEq(instance.balanceOf(recipient), 100 * 10 ** 18, "Recipient should have 100 tokens");
    }
}
