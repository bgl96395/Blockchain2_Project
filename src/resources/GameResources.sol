// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

contract GameResources is ERC1155, AccessControl, Pausable {
    uint256 public constant RESOURCE_WOOD = 1;
    uint256 public constant RESOURCE_IRON = 2;
    uint256 public constant RESOURCE_GEM = 3;
    uint256 public constant ITEM_SWORD = 4;
    uint256 public constant ITEM_SHIELD = 5;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    error InvalidResourceId();
    error ZeroMintAmount();

    event GameResourceMinted(address indexed mintRecipient, uint256 indexed resourceId, uint256 mintedAmount);

    constructor(string memory metadataBaseUri, address protocolAdministrator) ERC1155(metadataBaseUri) {
        _grantRole(DEFAULT_ADMIN_ROLE, protocolAdministrator);
        _grantRole(MINTER_ROLE, protocolAdministrator);
        _grantRole(PAUSER_ROLE, protocolAdministrator);
    }

    function mintResource(address mintRecipient, uint256 resourceId, uint256 mintAmount)
        external
        whenNotPaused
        onlyRole(MINTER_ROLE)
    {
        if (resourceId == 0 || resourceId > ITEM_SHIELD) revert InvalidResourceId();
        if (mintAmount == 0) revert ZeroMintAmount();
        _mint(mintRecipient, resourceId, mintAmount, "");
        emit GameResourceMinted(mintRecipient, resourceId, mintAmount);
    }

    function mintBatch(address mintRecipient, uint256[] calldata resourceIds, uint256[] calldata mintAmounts)
        external
        whenNotPaused
        onlyRole(MINTER_ROLE)
    {
        _mintBatch(mintRecipient, resourceIds, mintAmounts, "");
    }

    function burnResource(address burnFromAddress, uint256 resourceId, uint256 burnAmount) external {
        if (burnFromAddress != msg.sender && !isApprovedForAll(burnFromAddress, msg.sender)) {
            revert("Not authorized to burn");
        }
        _burn(burnFromAddress, resourceId, burnAmount);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
