// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.25;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import "v4-periphery/src/libraries/PathKey.sol";
interface ISuperDCAPoolV1_UV4StateInitializer {
    error PoolDoesNotExist();

    /**
     * @dev Returns true if the pool has not been initalized
     * @param poolManagerAddress The address of the pool manager
     * @param key The PoolKey of the pool to initialize
     */
    function isExistingPool(
        address poolManagerAddress,
        PoolKey calldata key
    ) external returns (bool _isExistingPool);

    /**
     * @dev Returns true if the pools have not been initalized
     * @param poolManagerAddress The address of the pool manager
     * @param keys The PoolKeys of the pools to initialize
     */
    function areAllExistingPools(
        address poolManagerAddress,
        PoolKey[] calldata keys
    ) external returns (bool allExistingPools);

    /**
     * @dev Sets Set [X,Z,Y],[ETH,X]
     * @param underlyingInputToken X
     * @param underlyingOutputToken Y
     */
    function getPathKeys(
        Currency underlyingInputToken,
        Currency underlyingOutputToken
    )
        external
        returns (PathKey[] memory swapPathKey, PathKey[] memory gasPathKey);

    /**
     * @dev underlyingInputToken Allows to spend 2 ** 256 - 1 to IV4Router"
     * @param routerAddress router to be allowed the spending
     * @param underlyingInputToken token allowing the spending
     */
    function safeMaxAllowance(
        address routerAddress,
        Currency underlyingInputToken
    ) external;
}
