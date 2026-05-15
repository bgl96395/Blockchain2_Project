// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { GameResources } from "../src/resources/GameResources.sol";
import { CraftingStation } from "../src/crafting/CraftingStation.sol";
import { ResourceMarketplace } from "../src/marketplace/ResourceMarketplace.sol";
import { NFTRentalVault } from "../src/rental/NFTRentalVault.sol";
import { LootBox } from "../src/lootbox/LootBox.sol";
import { GameToken } from "../src/governance/GameToken.sol";
import { GameTimelock } from "../src/governance/GameTimelock.sol";
import { GameGovernor } from "../src/governance/GameGovernor.sol";
import { PriceOracleAdapter } from "../src/oracle/PriceOracleAdapter.sol";
import { MarketplaceFactory } from "../src/factory/MarketplaceFactory.sol";
import { MarketplaceV1 } from "../src/upgradeable/MarketplaceV1.sol";
import { MockVRFCoordinator } from "../src/mocks/MockVRFCoordinator.sol";

contract DeployScript is Script {
    uint256 public constant MAXIMUM_TOKEN_SUPPLY = 1_000_000 ether;
    uint256 public constant TIMELOCK_DELAY_SECONDS = 2 days;
    uint256 public constant MAXIMUM_ORACLE_STALENESS = 3600;
    uint256 public constant LOOTBOX_COST_IN_WOOD = 100;
    uint256 public constant INITIAL_PROTOCOL_FEE_BASIS_POINTS = 50;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deployer address:", deployerAddress);

        GameToken gameToken = new GameToken(MAXIMUM_TOKEN_SUPPLY, deployerAddress);
        console2.log("GameToken deployed:", address(gameToken));

        address[] memory timelockProposers = new address[](0);
        address[] memory timelockExecutors = new address[](1);
        timelockExecutors[0] = address(0);
        GameTimelock gameTimelock =
            new GameTimelock(TIMELOCK_DELAY_SECONDS, timelockProposers, timelockExecutors, deployerAddress);
        console2.log("GameTimelock deployed:", address(gameTimelock));

        GameGovernor gameGovernor = new GameGovernor(gameToken, gameTimelock);
        console2.log("GameGovernor deployed:", address(gameGovernor));

        gameTimelock.grantRole(gameTimelock.PROPOSER_ROLE(), address(gameGovernor));
        gameTimelock.grantRole(gameTimelock.CANCELLER_ROLE(), address(gameGovernor));

        GameResources gameResources = new GameResources("https://api.cryptorealm/{id}.json", deployerAddress);
        console2.log("GameResources deployed:", address(gameResources));

        CraftingStation craftingStation = new CraftingStation(address(gameResources), deployerAddress);
        console2.log("CraftingStation deployed:", address(craftingStation));

        gameResources.grantRole(gameResources.MINTER_ROLE(), address(craftingStation));

        ResourceMarketplace resourceMarketplace = new ResourceMarketplace(address(gameResources));
        console2.log("ResourceMarketplace deployed:", address(resourceMarketplace));

        NFTRentalVault rentalVault = new NFTRentalVault(gameToken, address(gameResources), deployerAddress);
        console2.log("NFTRentalVault deployed:", address(rentalVault));

        MockVRFCoordinator vrfCoordinator = new MockVRFCoordinator();
        console2.log("MockVRFCoordinator deployed:", address(vrfCoordinator));

        LootBox lootBox =
            new LootBox(address(vrfCoordinator), address(gameResources), LOOTBOX_COST_IN_WOOD, deployerAddress);
        console2.log("LootBox deployed:", address(lootBox));

        vrfCoordinator.setConsumer(address(lootBox));
        gameResources.grantRole(gameResources.MINTER_ROLE(), address(lootBox));

        PriceOracleAdapter priceOracle = new PriceOracleAdapter(MAXIMUM_ORACLE_STALENESS, deployerAddress);
        console2.log("PriceOracleAdapter deployed:", address(priceOracle));

        MarketplaceFactory marketplaceFactory = new MarketplaceFactory(deployerAddress);
        console2.log("MarketplaceFactory deployed:", address(marketplaceFactory));

        MarketplaceV1 marketplaceImplementation = new MarketplaceV1();
        bytes memory initData = abi.encodeWithSelector(
            MarketplaceV1.initialize.selector, deployerAddress, deployerAddress, INITIAL_PROTOCOL_FEE_BASIS_POINTS
        );
        ERC1967Proxy marketplaceProxy = new ERC1967Proxy(address(marketplaceImplementation), initData);
        console2.log("MarketplaceV1 implementation:", address(marketplaceImplementation));
        console2.log("MarketplaceV1 proxy:", address(marketplaceProxy));

        gameToken.grantRole(gameToken.DEFAULT_ADMIN_ROLE(), address(gameTimelock));
        gameResources.grantRole(gameResources.DEFAULT_ADMIN_ROLE(), address(gameTimelock));

        vm.stopBroadcast();

        console2.log("Deployment completed");
    }
}
