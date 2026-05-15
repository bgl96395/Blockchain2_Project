// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract NFTRentalVault is ERC4626, ReentrancyGuard, AccessControl, IERC1155Receiver {
    using SafeERC20 for IERC20;
    bytes32 public constant RENTAL_MANAGER_ROLE = keccak256("RENTAL_MANAGER_ROLE");

    IERC1155 public immutable gameResources;

    struct RentalAgreement {
        address renterAddress;
        uint256 rentedItemId;
        uint256 rentedItemAmount;
        uint256 rentalEndTimestamp;
        uint256 collateralStaked;
        bool isActive;
    }

    mapping(uint256 rentalId => RentalAgreement agreement) public rentalAgreements;
    uint256 public nextRentalId;
    uint256 public totalCollateralLocked;

    error RentalDoesNotExist();
    error RentalAlreadyEnded();
    error InsufficientCollateral();
    error RentalNotExpiredYet();

    event RentalCreated(
        uint256 indexed rentalId, address indexed renter, uint256 itemId, uint256 itemAmount, uint256 endTimestamp
    );
    event RentalEnded(uint256 indexed rentalId, address indexed renter);

    constructor(IERC20 stakingTokenAddress, address gameResourcesAddress, address rentalAdministrator)
        ERC4626(stakingTokenAddress)
        ERC20("Rental Vault Share", "rvSHARE")
    {
        gameResources = IERC1155(gameResourcesAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, rentalAdministrator);
        _grantRole(RENTAL_MANAGER_ROLE, rentalAdministrator);
    }

    function createRental(
        address renterAddress,
        uint256 itemId,
        uint256 itemAmount,
        uint256 rentalDurationInSeconds,
        uint256 collateralAmount
    ) external onlyRole(RENTAL_MANAGER_ROLE) nonReentrant returns (uint256 rentalId) {
        if (collateralAmount == 0) revert InsufficientCollateral();

        IERC20(asset()).safeTransferFrom(renterAddress, address(this), collateralAmount);

        rentalId = nextRentalId++;
        rentalAgreements[rentalId] = RentalAgreement({
            renterAddress: renterAddress,
            rentedItemId: itemId,
            rentedItemAmount: itemAmount,
            rentalEndTimestamp: block.timestamp + rentalDurationInSeconds,
            collateralStaked: collateralAmount,
            isActive: true
        });

        totalCollateralLocked += collateralAmount;
        gameResources.safeTransferFrom(address(this), renterAddress, itemId, itemAmount, "");

        emit RentalCreated(rentalId, renterAddress, itemId, itemAmount, block.timestamp + rentalDurationInSeconds);
    }

    function endRental(uint256 rentalId) external nonReentrant {
        RentalAgreement storage agreement = rentalAgreements[rentalId];
        if (!agreement.isActive) revert RentalAlreadyEnded();
        if (block.timestamp < agreement.rentalEndTimestamp) revert RentalNotExpiredYet();

        agreement.isActive = false;
        totalCollateralLocked -= agreement.collateralStaked;

        IERC20(asset()).safeTransfer(agreement.renterAddress, agreement.collateralStaked);

        emit RentalEnded(rentalId, agreement.renterAddress);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl, IERC165) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
    }
}

