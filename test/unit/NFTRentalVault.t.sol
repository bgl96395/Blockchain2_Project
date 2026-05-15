// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { NFTRentalVault } from "../../src/rental/NFTRentalVault.sol";
import { GameResources } from "../../src/resources/GameResources.sol";
import { GameToken } from "../../src/governance/GameToken.sol";

contract NFTRentalVaultTest is Test {
    NFTRentalVault public vault;
    GameResources public gameResources;
    GameToken public stakingToken;

    address public constant ADMIN_ADDRESS = address(0xAD314);
    address public constant RENTER_ALICE = address(0xA11CE);

    function setUp() public {
        gameResources = new GameResources("https://api.gamefi/{id}.json", ADMIN_ADDRESS);
        stakingToken = new GameToken(1_000_000 ether, ADMIN_ADDRESS);
        vault = new NFTRentalVault(stakingToken, address(gameResources), ADMIN_ADDRESS);

        vm.startPrank(ADMIN_ADDRESS);
        stakingToken.mintTokens(RENTER_ALICE, 10_000 ether);
        gameResources.grantRole(gameResources.MINTER_ROLE(), address(this));
        vm.stopPrank();

        gameResources.mintResource(address(vault), 4, 100);
    }

    function test_Constructor_SetsAssetAndResources() public view {
        assertEq(vault.asset(), address(stakingToken));
        assertEq(address(vault.gameResources()), address(gameResources));
    }

    function test_CreateRental_TransfersCollateralAndItem() public {
        vm.prank(RENTER_ALICE);
        stakingToken.approve(address(vault), 1000 ether);

        vm.prank(ADMIN_ADDRESS);
        uint256 rentalId = vault.createRental(RENTER_ALICE, 4, 1, 1 days, 1000 ether);

        assertEq(rentalId, 0);
        assertEq(gameResources.balanceOf(RENTER_ALICE, 4), 1);
        assertEq(stakingToken.balanceOf(address(vault)), 1000 ether);
    }

    function test_CreateRental_RevertWhen_CallerNotAdmin() public {
        vm.prank(RENTER_ALICE);
        vm.expectRevert();
        vault.createRental(RENTER_ALICE, 4, 1, 1 days, 1000 ether);
    }

    function test_CreateRental_RevertWhen_ZeroCollateral() public {
        vm.prank(ADMIN_ADDRESS);
        vm.expectRevert(NFTRentalVault.InsufficientCollateral.selector);
        vault.createRental(RENTER_ALICE, 4, 1, 1 days, 0);
    }

    function test_EndRental_ReturnsCollateralAfterExpiration() public {
        vm.prank(RENTER_ALICE);
        stakingToken.approve(address(vault), 1000 ether);

        vm.prank(ADMIN_ADDRESS);
        vault.createRental(RENTER_ALICE, 4, 1, 1 days, 1000 ether);

        vm.warp(block.timestamp + 2 days);

        vault.endRental(0);

        assertEq(stakingToken.balanceOf(RENTER_ALICE), 10_000 ether);
    }

    function test_EndRental_RevertWhen_NotExpired() public {
        vm.prank(RENTER_ALICE);
        stakingToken.approve(address(vault), 1000 ether);

        vm.prank(ADMIN_ADDRESS);
        vault.createRental(RENTER_ALICE, 4, 1, 1 days, 1000 ether);

        vm.expectRevert(NFTRentalVault.RentalNotExpiredYet.selector);
        vault.endRental(0);
    }

    function test_EndRental_RevertWhen_AlreadyEnded() public {
        vm.prank(RENTER_ALICE);
        stakingToken.approve(address(vault), 1000 ether);

        vm.prank(ADMIN_ADDRESS);
        vault.createRental(RENTER_ALICE, 4, 1, 1 days, 1000 ether);

        vm.warp(block.timestamp + 2 days);
        vault.endRental(0);

        vm.expectRevert(NFTRentalVault.RentalAlreadyEnded.selector);
        vault.endRental(0);
    }
}
