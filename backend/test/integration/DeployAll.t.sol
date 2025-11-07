// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeployAll} from "script/DeployAll.s.sol";
import {MRTokenV1} from "src/MRToken/MRTokenV1.sol";
import {MerkleDistributorV1} from "src/MerkleDistributor/MerkleDistributorV1.sol";
import {StakingVaultV1} from "src/StakingVault/StakingVaultV1.sol";
import {MRTNFTokenV1} from "src/MRTNFToken/MRTNFTokenV1.sol";
import {CodeConstants} from "utils/CodeConstants.sol";

contract DeployAllTest is Test, CodeConstants {
    address internal constant CLAIMER = address(0xBEEF);
    address internal constant MINTER = address(0xBEEF);

    MRTokenV1 mrToken;
    MerkleDistributorV1 merkleDistributor;
    StakingVaultV1 stakingVault;
    MRTNFTokenV1 mrtnfToken;

    bytes32[] internal validProof;

    function setUp() public {
        vm.deal(MINTER, 10 ether);

        vm.setEnv("PRIVATE_KEY", "1");
        DeployAll.DeployAllReturn memory deployAllReturn = new DeployAll().run();

        mrToken = MRTokenV1(deployAllReturn.mrTokenProxyAddress);
        merkleDistributor = MerkleDistributorV1(deployAllReturn.merkleDistributorProxyAddress);
        stakingVault = StakingVaultV1(deployAllReturn.stakingVaultProxyAddress);
        mrtnfToken = MRTNFTokenV1(deployAllReturn.mrtnfTokenProxyAddress);

        // Set up valid proof for the claimer
        address deployer = mrToken.owner();
        bytes32 leaf = keccak256(abi.encodePacked(CLAIMER, uint256(REWARD_AMOUNT), uint64(0)));
        validProof = new bytes32[](0);

        vm.startPrank(deployer);
        merkleDistributor.setRoot(leaf, 0);
        mrToken.transfer(address(merkleDistributor), REWARD_AMOUNT * 10);
        vm.stopPrank();

        assertEq(mrToken.balanceOf(address(merkleDistributor)), REWARD_AMOUNT * 10);
    }

    function test_claimRewardFailsWithInvalidRound() public {
        vm.expectRevert(MerkleDistributorV1.MerkleDistributor__WrongRound.selector);
        merkleDistributor.claim(1, CLAIMER, REWARD_AMOUNT, validProof);
    }

    function test_claimRewardFailsWithInvalidAmount() public {
        vm.expectRevert(MerkleDistributorV1.MerkleDistributor__WrongAmount.selector);
        merkleDistributor.claim(0, CLAIMER, REWARD_AMOUNT + 1, validProof);
    }

    function test_claimRewardFailsWithInvalidProof() public {
        vm.expectRevert(MerkleDistributorV1.MerkleDistributor__BadProof.selector);
        merkleDistributor.claim(0, address(0xDEAD), REWARD_AMOUNT, validProof);
    }

    function test_claimRewardFailsWithAlreadyClaimed() public {
        vm.prank(CLAIMER);
        merkleDistributor.claim(0, CLAIMER, REWARD_AMOUNT, validProof);

        vm.expectRevert(MerkleDistributorV1.MerkleDistributor__AlreadyClaimed.selector);
        vm.prank(CLAIMER);
        merkleDistributor.claim(0, CLAIMER, REWARD_AMOUNT, validProof);
    }

    function test_mintNftFailsMintTooSoon() public {
        vm.prank(MINTER);
        mrtnfToken.mint{value: MINT_PRICE}(1);

        vm.prank(MINTER);
        vm.expectRevert(MRTNFTokenV1.MRTNFToken__MintTooSoon.selector);
        mrtnfToken.mint{value: MINT_PRICE}(1);
    }

    function test_fullFlow() public {
        // 1. NFT Mint
        vm.prank(MINTER);
        mrtnfToken.mint{value: MINT_PRICE}(1);
        assertEq(mrtnfToken.ownerOf(1), MINTER);

        // 2. Claim Reward
        vm.prank(CLAIMER);
        merkleDistributor.claim(0, CLAIMER, REWARD_AMOUNT, validProof);
        assertEq(mrToken.balanceOf(CLAIMER), REWARD_AMOUNT);

        // 3. Stake
        vm.startPrank(CLAIMER);
        mrToken.approve(address(stakingVault), REWARD_AMOUNT);
        stakingVault.stake(REWARD_AMOUNT);
        vm.stopPrank();
        assertEq(stakingVault.balanceOf(CLAIMER), REWARD_AMOUNT);

        //4. Withdraw
        vm.prank(CLAIMER);
        stakingVault.withdraw(REWARD_AMOUNT);
        assertEq(mrToken.balanceOf(CLAIMER), REWARD_AMOUNT);
        assertEq(stakingVault.balanceOf(CLAIMER), 0);
        assertEq(mrToken.balanceOf(address(stakingVault)), 0);
        assertEq(mrtnfToken.ownerOf(1), CLAIMER);

        // 5. Claim Reward again
        vm.expectRevert(MerkleDistributorV1.MerkleDistributor__AlreadyClaimed.selector);
        vm.prank(CLAIMER);
        merkleDistributor.claim(0, CLAIMER, REWARD_AMOUNT, validProof);
    }
}