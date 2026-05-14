// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IResourceMarketplace } from "../interfaces/IResourceMarketplace.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract ResourceMarketplace is IResourceMarketplace, ReentrancyGuard, IERC1155Receiver, AccessControl, Pausable {
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 public constant FEE_NUMERATOR = 997;
    uint256 public constant FEE_DENOMINATOR = 1000;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

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
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
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
        whenNotPaused
        returns (
            uint256 firstResourceAmountDeposited,
            uint256 secondResourceAmountDeposited,
            uint256 liquidityTokensMinted
        )
    {
        if (block.timestamp > transactionDeadline) {
            revert TransactionDeadlineExpired();
        }

        bytes32 poolKey = _computePoolKey(firstResourceId, secondResourceId);
        (
            uint256 smallerId,
            uint256 largerId,
            uint256 amountForSmaller,
            uint256 amountForLarger,
            uint256 minSmaller,
            uint256 minLarger
        ) = _orderInputs(
            firstResourceId,
            secondResourceId,
            firstResourceAmountDesired,
            secondResourceAmountDesired,
            firstResourceAmountMinimum,
            secondResourceAmountMinimum
        );

        LiquidityPool storage pool = liquidityPools[poolKey];

        (uint256 actualSmallerAmount, uint256 actualLargerAmount) =
            _calculateOptimalDeposit(pool, amountForSmaller, amountForLarger, minSmaller, minLarger);

        gameResources.safeTransferFrom(msg.sender, address(this), smallerId, actualSmallerAmount, "");
        gameResources.safeTransferFrom(msg.sender, address(this), largerId, actualLargerAmount, "");

        liquidityTokensMinted =
            _mintLiquidityTokens(pool, poolKey, liquidityRecipient, actualSmallerAmount, actualLargerAmount);

        pool.firstResourceReserve += actualSmallerAmount;
        pool.secondResourceReserve += actualLargerAmount;

        (firstResourceAmountDeposited, secondResourceAmountDeposited) = firstResourceId < secondResourceId
            ? (actualSmallerAmount, actualLargerAmount)
            : (actualLargerAmount, actualSmallerAmount);

        emit LiquidityAdded(
            liquidityRecipient,
            firstResourceId,
            secondResourceId,
            firstResourceAmountDeposited,
            secondResourceAmountDeposited,
            liquidityTokensMinted
        );
    }

    function _orderInputs(
        uint256 firstResourceId,
        uint256 secondResourceId,
        uint256 firstAmountDesired,
        uint256 secondAmountDesired,
        uint256 firstAmountMinimum,
        uint256 secondAmountMinimum
    )
        private
        pure
        returns (
            uint256 smallerId,
            uint256 largerId,
            uint256 amountForSmaller,
            uint256 amountForLarger,
            uint256 minimumForSmaller,
            uint256 minimumForLarger
        )
    {
        if (firstResourceId < secondResourceId) {
            return (
                firstResourceId,
                secondResourceId,
                firstAmountDesired,
                secondAmountDesired,
                firstAmountMinimum,
                secondAmountMinimum
            );
        }
        return (
            secondResourceId,
            firstResourceId,
            secondAmountDesired,
            firstAmountDesired,
            secondAmountMinimum,
            firstAmountMinimum
        );
    }

    function _calculateOptimalDeposit(
        LiquidityPool storage pool,
        uint256 smallerAmountDesired,
        uint256 largerAmountDesired,
        uint256 smallerAmountMinimum,
        uint256 largerAmountMinimum
    ) private view returns (uint256 actualSmallerAmount, uint256 actualLargerAmount) {
        uint256 currentSmallerReserve = pool.firstResourceReserve;
        uint256 currentLargerReserve = pool.secondResourceReserve;

        if (currentSmallerReserve == 0 && currentLargerReserve == 0) {
            return (smallerAmountDesired, largerAmountDesired);
        }

        uint256 largerAmountOptimal = (smallerAmountDesired * currentLargerReserve) / currentSmallerReserve;
        if (largerAmountOptimal <= largerAmountDesired) {
            if (largerAmountOptimal < largerAmountMinimum) revert InsufficientLiquidityMinted();
            return (smallerAmountDesired, largerAmountOptimal);
        }

        uint256 smallerAmountOptimal = (largerAmountDesired * currentSmallerReserve) / currentLargerReserve;
        if (smallerAmountOptimal < smallerAmountMinimum) revert InsufficientLiquidityMinted();
        return (smallerAmountOptimal, largerAmountDesired);
    }

    function _mintLiquidityTokens(
        LiquidityPool storage pool,
        bytes32 poolKey,
        address liquidityRecipient,
        uint256 smallerAmount,
        uint256 largerAmount
    ) private returns (uint256 liquidityTokensMinted) {
        uint256 currentTotalSupply = pool.totalLiquiditySupply;

        if (currentTotalSupply == 0) {
            liquidityTokensMinted = _squareRoot(smallerAmount * largerAmount);
            if (liquidityTokensMinted <= MINIMUM_LIQUIDITY) revert InsufficientLiquidityMinted();
            liquidityTokensMinted -= MINIMUM_LIQUIDITY;
            pool.totalLiquiditySupply = liquidityTokensMinted + MINIMUM_LIQUIDITY;
            liquidityBalanceOf[poolKey][address(0)] = MINIMUM_LIQUIDITY;
        } else {
            uint256 mintedFromSmaller = (smallerAmount * currentTotalSupply) / pool.firstResourceReserve;
            uint256 mintedFromLarger = (largerAmount * currentTotalSupply) / pool.secondResourceReserve;
            liquidityTokensMinted = mintedFromSmaller < mintedFromLarger ? mintedFromSmaller : mintedFromLarger;
            if (liquidityTokensMinted == 0) revert InsufficientLiquidityMinted();
            pool.totalLiquiditySupply = currentTotalSupply + liquidityTokensMinted;
        }

        liquidityBalanceOf[poolKey][liquidityRecipient] += liquidityTokensMinted;
    }

    function _squareRoot(uint256 inputValue) private pure returns (uint256 squareRootResult) {
        if (inputValue == 0) return 0;
        uint256 currentEstimate = inputValue;
        uint256 nextEstimate = (inputValue + 1) / 2;
        while (nextEstimate < currentEstimate) {
            currentEstimate = nextEstimate;
            nextEstimate = (inputValue / nextEstimate + nextEstimate) / 2;
        }
        return currentEstimate;
    }

    function removeLiquidity(
        uint256 firstResourceId,
        uint256 secondResourceId,
        uint256 liquidityTokensToBurn,
        uint256 firstResourceAmountMinimum,
        uint256 secondResourceAmountMinimum,
        address resourceRecipient,
        uint256 transactionDeadline
    )
        external
        nonReentrant
        whenNotPaused
        returns (uint256 firstResourceAmountWithdrawn, uint256 secondResourceAmountWithdrawn)
    {
        if (block.timestamp > transactionDeadline) revert TransactionDeadlineExpired();

        bytes32 poolKey = _computePoolKey(firstResourceId, secondResourceId);
        LiquidityPool storage pool = liquidityPools[poolKey];

        if (pool.totalLiquiditySupply == 0) revert PoolDoesNotExist();
        if (liquidityBalanceOf[poolKey][msg.sender] < liquidityTokensToBurn) {
            revert InsufficientLiquidityBurned();
        }

        uint256 smallerAmountWithdrawn = (liquidityTokensToBurn * pool.firstResourceReserve) / pool.totalLiquiditySupply;
        uint256 largerAmountWithdrawn = (liquidityTokensToBurn * pool.secondResourceReserve) / pool.totalLiquiditySupply;

        if (smallerAmountWithdrawn == 0 || largerAmountWithdrawn == 0) revert InsufficientLiquidityBurned();

        (uint256 minSmaller, uint256 minLarger) = firstResourceId < secondResourceId
            ? (firstResourceAmountMinimum, secondResourceAmountMinimum)
            : (secondResourceAmountMinimum, firstResourceAmountMinimum);

        if (smallerAmountWithdrawn < minSmaller) revert InsufficientLiquidityBurned();
        if (largerAmountWithdrawn < minLarger) revert InsufficientLiquidityBurned();

        liquidityBalanceOf[poolKey][msg.sender] -= liquidityTokensToBurn;
        pool.totalLiquiditySupply -= liquidityTokensToBurn;
        pool.firstResourceReserve -= smallerAmountWithdrawn;
        pool.secondResourceReserve -= largerAmountWithdrawn;

        (uint256 smallerId, uint256 largerId) = firstResourceId < secondResourceId
            ? (firstResourceId, secondResourceId)
            : (secondResourceId, firstResourceId);

        gameResources.safeTransferFrom(address(this), resourceRecipient, smallerId, smallerAmountWithdrawn, "");
        gameResources.safeTransferFrom(address(this), resourceRecipient, largerId, largerAmountWithdrawn, "");

        (firstResourceAmountWithdrawn, secondResourceAmountWithdrawn) = firstResourceId < secondResourceId
            ? (smallerAmountWithdrawn, largerAmountWithdrawn)
            : (largerAmountWithdrawn, smallerAmountWithdrawn);

        emit LiquidityRemoved(
            msg.sender,
            firstResourceId,
            secondResourceId,
            firstResourceAmountWithdrawn,
            secondResourceAmountWithdrawn,
            liquidityTokensToBurn
        );
    }

    function swapExactInputForOutput(
        uint256 inputResourceId,
        uint256 outputResourceId,
        uint256 inputResourceAmount,
        uint256 minimumOutputResourceAmount,
        address outputRecipient,
        uint256 transactionDeadline
    ) external nonReentrant whenNotPaused returns (uint256 outputResourceAmount) {
        if (block.timestamp > transactionDeadline) revert TransactionDeadlineExpired();
        if (inputResourceAmount == 0) revert InsufficientInputAmount();

        bytes32 poolKey = _computePoolKey(inputResourceId, outputResourceId);
        LiquidityPool storage pool = liquidityPools[poolKey];

        if (pool.totalLiquiditySupply == 0) revert PoolDoesNotExist();

        bool inputIsSmaller = inputResourceId < outputResourceId;
        uint256 inputReserve = inputIsSmaller ? pool.firstResourceReserve : pool.secondResourceReserve;
        uint256 outputReserve = inputIsSmaller ? pool.secondResourceReserve : pool.firstResourceReserve;

        uint256 inputAmountWithFee = inputResourceAmount * FEE_NUMERATOR;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * FEE_DENOMINATOR) + inputAmountWithFee;
        outputResourceAmount = numerator / denominator;

        if (outputResourceAmount < minimumOutputResourceAmount) revert InsufficientOutputAmount();
        if (outputResourceAmount >= outputReserve) revert InsufficientOutputAmount();

        gameResources.safeTransferFrom(msg.sender, address(this), inputResourceId, inputResourceAmount, "");
        gameResources.safeTransferFrom(address(this), outputRecipient, outputResourceId, outputResourceAmount, "");

        if (inputIsSmaller) {
            pool.firstResourceReserve += inputResourceAmount;
            pool.secondResourceReserve -= outputResourceAmount;
        } else {
            pool.secondResourceReserve += inputResourceAmount;
            pool.firstResourceReserve -= outputResourceAmount;
        }

        uint256 newProduct = pool.firstResourceReserve * pool.secondResourceReserve;
        uint256 oldProduct = inputReserve * outputReserve;
        if (newProduct < oldProduct) revert ConstantProductInvariantViolated();

        emit ResourcesSwapped(msg.sender, inputResourceId, outputResourceId, inputResourceAmount, outputResourceAmount);
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

    function pauseMarketplace() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpauseMarketplace() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl, IERC165) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
    }
}
