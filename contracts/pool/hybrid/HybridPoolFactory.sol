// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.0;

import "../../abstract/Factory.sol";

import "./HybridPool.sol";

/// @notice Contract for deploying Trident exchange Hybrid Pool with configurations.
/// @author Mudit Gupta.
contract HybridPoolFactory is Factory {
    constructor(address _masterDeployer) Factory(_masterDeployer) {}

    function deployPool(bytes memory _deployData) external override returns (address pool) {
        (address tokenA, address tokenB, uint256 swapFee, uint256 a) = abi.decode(_deployData, (address, address, uint256, uint256));

        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }

        // @dev Strips any extra data.
        _deployData = abi.encode(tokenA, tokenB, swapFee, a);
        address[] memory tokens = new address[](2);
        tokens[0] = tokenA;
        tokens[1] = tokenB;

        // @dev Salt is not actually needed since `_deployData` is part of creationCode and already contains the salt.
        bytes32 salt = keccak256(_deployData);
        pool = address(new HybridPool{salt: salt}(_deployData, masterDeployer));
        _registerPool(pool, tokens, salt);
    }
}
