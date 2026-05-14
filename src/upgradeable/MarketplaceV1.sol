// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MarketplaceV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 public protocolFeePercentageInBasisPoints;
    address public protocolFeeRecipient;
    uint256 public totalProtocolFeesCollected;

    mapping(address user => uint256 lastInteractionTimestamp) public lastUserInteraction;

    event ProtocolFeeUpdated(uint256 oldFeePercentage, uint256 newFeePercentage);
    event ProtocolFeeRecipientUpdated(address oldRecipient, address newRecipient);
    event UserInteractionRecorded(address indexed user, uint256 timestamp);

    error FeePercentageExceedsMaximum();
    error ZeroAddressNotAllowed();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, address feeRecipient, uint256 initialFeePercentage) public initializer {
        __Ownable_init(initialOwner);

        if (initialFeePercentage > 1000) revert FeePercentageExceedsMaximum();
        if (feeRecipient == address(0)) revert ZeroAddressNotAllowed();

        protocolFeePercentageInBasisPoints = initialFeePercentage;
        protocolFeeRecipient = feeRecipient;
    }

    function recordUserInteraction() external {
        lastUserInteraction[msg.sender] = block.timestamp;
        emit UserInteractionRecorded(msg.sender, block.timestamp);
    }

    function setProtocolFee(uint256 newFeePercentage) external onlyOwner {
        if (newFeePercentage > 1000) revert FeePercentageExceedsMaximum();
        uint256 oldFee = protocolFeePercentageInBasisPoints;
        protocolFeePercentageInBasisPoints = newFeePercentage;
        emit ProtocolFeeUpdated(oldFee, newFeePercentage);
    }

    function setProtocolFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddressNotAllowed();
        address oldRecipient = protocolFeeRecipient;
        protocolFeeRecipient = newRecipient;
        emit ProtocolFeeRecipientUpdated(oldRecipient, newRecipient);
    }

    function getContractVersion() external pure virtual returns (string memory) {
        return "1.0.0";
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}
