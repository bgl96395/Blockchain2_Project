// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract GameToken is ERC20, ERC20Permit, ERC20Votes, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 public immutable maximumTokenSupply;

    error ExceedsMaximumSupply();

    constructor(uint256 maximumSupplyCap, address protocolAdministrator)
        ERC20("Crypto Realm Token", "REALM")
        ERC20Permit("Crypto Realm Token")
    {
        maximumTokenSupply = maximumSupplyCap;
        _grantRole(DEFAULT_ADMIN_ROLE, protocolAdministrator);
        _grantRole(MINTER_ROLE, protocolAdministrator);
    }

    function mintTokens(address mintRecipient, uint256 mintAmount) external onlyRole(MINTER_ROLE) {
        if (totalSupply() + mintAmount > maximumTokenSupply) revert ExceedsMaximumSupply();
        _mint(mintRecipient, mintAmount);
    }

    function nonces(address tokenOwner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(tokenOwner);
    }

    function _update(address transferFrom, address transferTo, uint256 transferAmount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(transferFrom, transferTo, transferAmount);
    }
}
