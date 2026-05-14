// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ResourceMarketplace } from "../marketplace/ResourceMarketplace.sol";

contract MarketplaceFactory {
    address public immutable factoryAdministrator;

    mapping(address gameResourcesAddress => address marketplaceAddress) public marketplaceForResources;
    address[] public allDeployedMarketplaces;

    event MarketplaceDeployedWithCreate(address indexed gameResources, address indexed deployedMarketplace);
    event MarketplaceDeployedWithCreate2(
        address indexed gameResources, address indexed deployedMarketplace, bytes32 deploymentSalt
    );

    error MarketplaceAlreadyExists();
    error UnauthorizedDeployer();

    constructor(address administratorAddress) {
        factoryAdministrator = administratorAddress;
    }

    function deployMarketplaceWithCreate(address gameResourcesAddress) external returns (address deployedAddress) {
        if (msg.sender != factoryAdministrator) revert UnauthorizedDeployer();
        if (marketplaceForResources[gameResourcesAddress] != address(0)) revert MarketplaceAlreadyExists();

        ResourceMarketplace newMarketplace = new ResourceMarketplace(gameResourcesAddress);
        deployedAddress = address(newMarketplace);

        marketplaceForResources[gameResourcesAddress] = deployedAddress;
        allDeployedMarketplaces.push(deployedAddress);

        emit MarketplaceDeployedWithCreate(gameResourcesAddress, deployedAddress);
    }

    function deployMarketplaceWithCreate2(address gameResourcesAddress, bytes32 deploymentSalt)
        external
        returns (address deployedAddress)
    {
        if (msg.sender != factoryAdministrator) revert UnauthorizedDeployer();

        bytes memory creationBytecode =
            abi.encodePacked(type(ResourceMarketplace).creationCode, abi.encode(gameResourcesAddress));

        assembly {
            deployedAddress := create2(0, add(creationBytecode, 0x20), mload(creationBytecode), deploymentSalt)
            if iszero(deployedAddress) { revert(0, 0) }
        }

        allDeployedMarketplaces.push(deployedAddress);

        emit MarketplaceDeployedWithCreate2(gameResourcesAddress, deployedAddress, deploymentSalt);
    }

    function predictMarketplaceAddress(address gameResourcesAddress, bytes32 deploymentSalt)
        external
        view
        returns (address predictedAddress)
    {
        bytes memory creationBytecode =
            abi.encodePacked(type(ResourceMarketplace).creationCode, abi.encode(gameResourcesAddress));
        bytes32 bytecodeHash = keccak256(creationBytecode);

        predictedAddress = address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), deploymentSalt, bytecodeHash))))
        );
    }

    function getTotalDeployedMarketplaces() external view returns (uint256) {
        return allDeployedMarketplaces.length;
    }
}
