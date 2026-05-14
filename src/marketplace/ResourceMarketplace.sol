// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IResourceMarketplace } from "../interfaces/IResourceMarketplace.sol";

contract ResourceMarketplace is IResourceMarketplace, ReentrancyGuard, IERC1155Receiver {
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 public constant FEE_NUMERATOR = 997;
    uint256 public constant FEE_DENOMINATOR = 1000;

    IERC1155 public immutable gameResources;

    struct LiquidityPool {
        uint256 firstResourceReserve;
        uint256 secondResourceReserve;
        uint256 totalLiquiditySupply;
    }

    mapping(bytes32 poolKey => LiquidityPool pool) private liquidityPools;
    mapping(bytes32 poolKey => mapping(address provider => uint256 balance)) public liquidityBalanceOf;

    error IdenticalResourceIds();
    error TransactionDeadlineExpired();
    error InsufficientLiquidityMinted();
    error InsufficientLiquidityBurned();
    error InsufficientOutputAmount();
    error InsufficientInputAmount();
    error PoolDoesNotExist();
    error ConstantProductInvariantViolated();

    constructor(address gameResourcesAddress) {
        gameResources = IERC1155(gameResourcesAddress);
    }

    function getPoolReserves(uint256 firstResourceId, uint256 secondResourceId)
        external
        view
        returns (uint256 firstReserve, uint256 secondReserve)
    {
        bytes32 poolKey = _computePoolKey(firstResourceId, secondResourceId);
        LiquidityPool memory pool = liquidityPools[poolKey];
        return (pool.firstResourceReserve, pool.secondResourceReserve);
    }

    function _computePoolKey(uint256 firstResourceId, uint256 secondResourceId) internal pure returns (bytes32) {
        if (firstResourceId == secondResourceId) revert IdenticalResourceIds();
        (uint256 smallerId, uint256 largerId) = firstResourceId < secondResourceId
            ? (firstResourceId, secondResourceId)
            : (secondResourceId, firstResourceId);
        return keccak256(abi.encodePacked(smallerId, largerId));
    }

    function addLiquidity(
        uint256 firstResourceId,
        uint256 secondResourceId,
        uint256 firstResourceAmountDesired,
        uint256 secondResourceAmountDesired,
        uint256 firstResourceAmountMinimum,
        uint256 secondResourceAmountMinimum,
        address liquidityRecipient,
        uint256 transactionDeadline
    )
        external
        nonReentrant
        returns (
            uint256 firstResourceAmountDeposited,
            uint256 secondResourceAmountDeposited,
            uint256 liquidityTokensMinted
        )
    {
        revert("Not implemented yet");
    }

    function removeLiquidity(
        uint256 firstResourceId,
        uint256 secondResourceId,
        uint256 liquidityTokensToBurn,
        uint256 firstResourceAmountMinimum,
        uint256 secondResourceAmountMinimum,
        address resourceRecipient,
        uint256 transactionDeadline
    ) external nonReentrant returns (uint256 firstResourceAmountWithdrawn, uint256 secondResourceAmountWithdrawn) {
        revert("Not implemented yet");
    }

    function swapExactInputForOutput(
        uint256 inputResourceId,
        uint256 outputResourceId,
        uint256 inputResourceAmount,
        uint256 minimumOutputResourceAmount,
        address outputRecipient,
        uint256 transactionDeadline
    ) external nonReentrant returns (uint256 outputResourceAmount) {
        revert("Not implemented yet");
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

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }
}
