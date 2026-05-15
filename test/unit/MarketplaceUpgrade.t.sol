// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { MarketplaceV1 } from "../../src/upgradeable/MarketplaceV1.sol";
import { MarketplaceV2 } from "../../src/upgradeable/MarketplaceV2.sol";

contract MarketplaceUpgradeTest is Test {
    MarketplaceV1 public marketplaceV1Implementation;
    MarketplaceV1 public marketplaceProxy;

    address public constant CONTRACT_OWNER = address(0xBEEF);
    address public constant FEE_RECIPIENT = address(0xFEE);
    address public constant USER_ALICE = address(0xA11CE);

    function setUp() public {
        marketplaceV1Implementation = new MarketplaceV1();

        bytes memory initializeCalldata =
            abi.encodeWithSelector(MarketplaceV1.initialize.selector, CONTRACT_OWNER, FEE_RECIPIENT, 50);

        ERC1967Proxy proxy = new ERC1967Proxy(address(marketplaceV1Implementation), initializeCalldata);
        marketplaceProxy = MarketplaceV1(address(proxy));
    }

    function test_Initialize_SetsInitialState() public view {
        assertEq(marketplaceProxy.owner(), CONTRACT_OWNER);
        assertEq(marketplaceProxy.protocolFeeRecipient(), FEE_RECIPIENT);
        assertEq(marketplaceProxy.protocolFeePercentageInBasisPoints(), 50);
    }

    function test_GetContractVersion_ReturnsV1() public view {
        assertEq(marketplaceProxy.getContractVersion(), "1.0.0");
    }

    function test_SetProtocolFee_OnlyOwnerCanUpdate() public {
        vm.prank(CONTRACT_OWNER);
        marketplaceProxy.setProtocolFee(100);
        assertEq(marketplaceProxy.protocolFeePercentageInBasisPoints(), 100);
    }

    function test_SetProtocolFee_RevertWhen_CallerNotOwner() public {
        vm.prank(USER_ALICE);
        vm.expectRevert();
        marketplaceProxy.setProtocolFee(100);
    }

    function test_UpgradeToV2_PreservesStateAndAddsFunctionality() public {
        vm.prank(CONTRACT_OWNER);
        marketplaceProxy.setProtocolFee(75);

        MarketplaceV2 marketplaceV2Implementation = new MarketplaceV2();

        vm.prank(CONTRACT_OWNER);
        marketplaceProxy.upgradeToAndCall(address(marketplaceV2Implementation), "");

        MarketplaceV2 upgradedProxy = MarketplaceV2(address(marketplaceProxy));

        assertEq(upgradedProxy.protocolFeePercentageInBasisPoints(), 75);
        assertEq(upgradedProxy.protocolFeeRecipient(), FEE_RECIPIENT);
        assertEq(upgradedProxy.getContractVersion(), "2.0.0");

        upgradedProxy.executeUpgradeOnlyFunction();
        assertEq(upgradedProxy.totalUpgradeCallsExecuted(), 1);
    }

    function test_UpgradeToV2_RevertWhen_CallerNotOwner() public {
        MarketplaceV2 marketplaceV2Implementation = new MarketplaceV2();

        vm.prank(USER_ALICE);
        vm.expectRevert();
        marketplaceProxy.upgradeToAndCall(address(marketplaceV2Implementation), "");
    }
}
