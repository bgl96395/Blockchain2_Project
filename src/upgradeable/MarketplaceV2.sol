// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { MarketplaceV1 } from "./MarketplaceV1.sol";

contract MarketplaceV2 is MarketplaceV1 {
    uint256 public totalUpgradeCallsExecuted;

    event UpgradeFunctionCalled(address indexed caller, uint256 totalCalls);

    function executeUpgradeOnlyFunction() external {
        totalUpgradeCallsExecuted++;
        emit UpgradeFunctionCalled(msg.sender, totalUpgradeCallsExecuted);
    }

    function getContractVersion() external pure override returns (string memory) {
        return "2.0.0";
    }
}
