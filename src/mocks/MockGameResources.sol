// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MockGameResources is ERC1155 {
    constructor() ERC1155("") { }

    function mint(address mintRecipient, uint256 resourceId, uint256 mintAmount) external {
        _mint(mintRecipient, resourceId, mintAmount, "");
    }
}
