// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { MarketplaceFactory } from "../../src/factory/MarketplaceFactory.sol";
import { MockGameResources } from "../../src/mocks/MockGameResources.sol";

contract MarketplaceFactoryTest is Test {
    MarketplaceFactory public factory;
    MockGameResources public gameResources;

    address public constant FACTORY_ADMINISTRATOR = address(0xAD314);
    address public constant UNAUTHORIZED_USER = address(0xBAD);

    function setUp() public {
        factory = new MarketplaceFactory(FACTORY_ADMINISTRATOR);
        gameResources = new MockGameResources();
    }

    function test_DeployWithCreate_AssignsValidAddress() public {
        vm.prank(FACTORY_ADMINISTRATOR);
        address deployed = factory.deployMarketplaceWithCreate(address(gameResources));

        assertTrue(deployed != address(0));
        assertEq(factory.marketplaceForResources(address(gameResources)), deployed);
        assertEq(factory.getTotalDeployedMarketplaces(), 1);
    }

    function test_DeployWithCreate_RevertWhen_AlreadyExists() public {
        vm.prank(FACTORY_ADMINISTRATOR);
        factory.deployMarketplaceWithCreate(address(gameResources));

        vm.prank(FACTORY_ADMINISTRATOR);
        vm.expectRevert(MarketplaceFactory.MarketplaceAlreadyExists.selector);
        factory.deployMarketplaceWithCreate(address(gameResources));
    }

    function test_DeployWithCreate_RevertWhen_CallerUnauthorized() public {
        vm.prank(UNAUTHORIZED_USER);
        vm.expectRevert(MarketplaceFactory.UnauthorizedDeployer.selector);
        factory.deployMarketplaceWithCreate(address(gameResources));
    }

    function test_DeployWithCreate2_MatchesPredictedAddress() public {
        bytes32 salt = keccak256("test-salt");

        address predicted = factory.predictMarketplaceAddress(address(gameResources), salt);

        vm.prank(FACTORY_ADMINISTRATOR);
        address actual = factory.deployMarketplaceWithCreate2(address(gameResources), salt);

        assertEq(predicted, actual);
    }

    function test_DeployWithCreate2_DifferentSaltsProduceDifferentAddresses() public {
        bytes32 firstSalt = keccak256("first");
        bytes32 secondSalt = keccak256("second");

        vm.prank(FACTORY_ADMINISTRATOR);
        address firstDeployment = factory.deployMarketplaceWithCreate2(address(gameResources), firstSalt);

        vm.prank(FACTORY_ADMINISTRATOR);
        address secondDeployment = factory.deployMarketplaceWithCreate2(address(gameResources), secondSalt);

        assertTrue(firstDeployment != secondDeployment);
    }

    function test_DeployWithCreate2_RevertWhen_CallerUnauthorized() public {
        bytes32 salt = keccak256("test-salt");

        vm.prank(UNAUTHORIZED_USER);
        vm.expectRevert(MarketplaceFactory.UnauthorizedDeployer.selector);
        factory.deployMarketplaceWithCreate2(address(gameResources), salt);
    }
}
