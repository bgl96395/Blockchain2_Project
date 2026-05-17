// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title GameToken
/// @notice Governance and utility token for the Crypto Realm protocol.
contract GameToken is ERC20, ERC20Permit, ERC20Votes, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 public immutable maximumTokenSupply;

    error ExceedsMaximumSupply();

    /// @notice Initializes the REALM token contract.
    /// @param maximumSupplyCap Maximum amount of REALM tokens that can ever exist.
    /// @param protocolAdministrator Address that receives admin and minter roles.
    constructor(uint256 maximumSupplyCap, address protocolAdministrator)
        ERC20("Crypto Realm Token", "REALM")
        ERC20Permit("Crypto Realm Token")
    {
        maximumTokenSupply = maximumSupplyCap;
        _grantRole(DEFAULT_ADMIN_ROLE, protocolAdministrator);
        _grantRole(MINTER_ROLE, protocolAdministrator);
    }

    /// @notice Mints new REALM tokens to the recipient.
    /// @dev Reverts if total supply exceeds maximumTokenSupply.
    /// @param mintRecipient Address receiving minted tokens.
    /// @param mintAmount Amount of tokens to mint.
    function mintTokens(address mintRecipient, uint256 mintAmount) external onlyRole(MINTER_ROLE) {
        if (totalSupply() + mintAmount > maximumTokenSupply) revert ExceedsMaximumSupply();
        _mint(mintRecipient, mintAmount);
    }

    /// @notice Returns the current nonce for permit signatures.
    /// @param tokenOwner Address of the token holder.
    /// @return Current nonce value.
    function nonces(address tokenOwner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(tokenOwner);
    }

    /// @notice Updates balances and voting power during token transfers.
    /// @param transferFrom Address sending tokens.
    /// @param transferTo Address receiving tokens.
    /// @param transferAmount Amount of transferred tokens.
    function _update(address transferFrom, address transferTo, uint256 transferAmount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(transferFrom, transferTo, transferAmount);
    }
}