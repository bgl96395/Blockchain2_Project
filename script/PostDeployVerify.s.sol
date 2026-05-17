// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script, console2 } from "forge-std/Script.sol";
import { GameToken } from "../src/governance/GameToken.sol";
import { GameTimelock } from "../src/governance/GameTimelock.sol";
import { GameGovernor } from "../src/governance/GameGovernor.sol";
import { GameResources } from "../src/resources/GameResources.sol";
import { ResourceMarketplace } from "../src/marketplace/ResourceMarketplace.sol";
import { PriceOracleAdapter } from "../src/oracle/PriceOracleAdapter.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

contract PostDeployVerifyScript is Script {
    address constant GAME_TOKEN = 0x169Ae7E53E9dAd50eDbBb07570d2Cdf79c3dE1b9;
    address constant GAME_TIMELOCK = 0x39a48859010118ac579d4A1e5cBb2348466cd665;
    address constant GAME_GOVERNOR = 0x9C8Cb7209Ac3153d43d6aB217C167F200dD9bB50;
    address constant GAME_RESOURCES = 0x4FF5ff07e6A926C5eb6CA90AdFa7ACD48Ff68B48;
    address constant RESOURCE_MARKETPLACE = 0xD15e44a413E0F299ea7e3C9cD7bE4c6b5e70Cf26;
    address constant PRICE_ORACLE = 0xd061264368e1f53b6BF2F2fbE39B9149eBFB68d3;

    uint256 constant EXPECTED_TIMELOCK_DELAY = 2 days;
    uint256 constant EXPECTED_VOTING_DELAY = 7200;
    uint256 constant EXPECTED_VOTING_PERIOD = 50400;
    uint256 constant EXPECTED_MAX_SUPPLY = 1_000_000 ether;
    uint256 constant EXPECTED_ORACLE_STALENESS = 3600;

    uint256 public verificationsPassed;
    uint256 public verificationsFailed;

    function run() external {
        console2.log("===========================================");
        console2.log("POST-DEPLOYMENT VERIFICATION SCRIPT");
        console2.log("Network: Base Sepolia (Chain ID 84532)");
        console2.log("===========================================");

        verifyGameToken();
        verifyGameTimelock();
        verifyGameGovernor();
        verifyResourcesAndMarketplace();
        verifyPriceOracle();
        verifyTimelockOwnership();

        console2.log("===========================================");
        console2.log("RESULTS");
        console2.log("Passed:", verificationsPassed);
        console2.log("Failed:", verificationsFailed);
        console2.log("===========================================");

        require(verificationsFailed == 0, "Verification failed");
    }

    function verifyGameToken() internal {
        GameToken token = GameToken(GAME_TOKEN);
        check("GameToken.name() == 'Crypto Realm Token'", keccak256(bytes(token.name())) == keccak256("Crypto Realm Token"));
        check("GameToken.symbol() == 'REALM'", keccak256(bytes(token.symbol())) == keccak256("REALM"));
        check("GameToken.maximumTokenSupply == 1M", token.maximumTokenSupply() == EXPECTED_MAX_SUPPLY);
    }

    function verifyGameTimelock() internal {
        GameTimelock timelock = GameTimelock(payable(GAME_TIMELOCK));
        check("GameTimelock.getMinDelay() == 2 days", timelock.getMinDelay() == EXPECTED_TIMELOCK_DELAY);
    }

    function verifyGameGovernor() internal {
        GameGovernor governor = GameGovernor(payable(GAME_GOVERNOR));
        check("GameGovernor.votingDelay() == 7200 blocks", governor.votingDelay() == EXPECTED_VOTING_DELAY);
        check("GameGovernor.votingPeriod() == 50400 blocks", governor.votingPeriod() == EXPECTED_VOTING_PERIOD);
        check("GameGovernor.timelock() == GameTimelock", governor.timelock() == GAME_TIMELOCK);
    }

    function verifyResourcesAndMarketplace() internal {
        GameResources resources = GameResources(GAME_RESOURCES);
        bytes32 minterRole = resources.MINTER_ROLE();
        check("GameResources.MINTER_ROLE exists", minterRole != bytes32(0));

        ResourceMarketplace marketplace = ResourceMarketplace(RESOURCE_MARKETPLACE);
        check("ResourceMarketplace.gameResources() == GameResources", address(marketplace.gameResources()) == GAME_RESOURCES);
    }

    function verifyPriceOracle() internal {
        PriceOracleAdapter oracle = PriceOracleAdapter(PRICE_ORACLE);
        check("PriceOracleAdapter.maximumStalenessSeconds() == 3600", oracle.maximumStalenessSeconds() == EXPECTED_ORACLE_STALENESS);
    }

    function verifyTimelockOwnership() internal {
        GameToken token = GameToken(GAME_TOKEN);
        GameResources resources = GameResources(GAME_RESOURCES);
        bytes32 adminRole = 0x00;
        check("GameTimelock holds DEFAULT_ADMIN_ROLE on GameToken", token.hasRole(adminRole, GAME_TIMELOCK));
        check("GameTimelock holds DEFAULT_ADMIN_ROLE on GameResources", resources.hasRole(adminRole, GAME_TIMELOCK));
    }

    function check(string memory description, bool condition) internal {
        if (condition) {
            console2.log("PASS:", description);
            verificationsPassed++;
        } else {
            console2.log("FAIL:", description);
            verificationsFailed++;
        }
    }
}