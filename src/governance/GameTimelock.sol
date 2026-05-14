// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

contract GameTimelock is TimelockController {
    constructor(uint256 minimumDelay, address[] memory proposers, address[] memory executors, address timelockAdmin)
        TimelockController(minimumDelay, proposers, executors, timelockAdmin)
    { }
}
