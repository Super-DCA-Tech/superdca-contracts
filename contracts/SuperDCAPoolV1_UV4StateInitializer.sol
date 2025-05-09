// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.25;

import "./interface/ISuperDCAPoolV1_UV4StateInitializer.sol";
import {IV4Router} from "v4-periphery/src/interfaces/IV4Router.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IERC20} from "openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";

contract SuperDCAPoolV1_UV4StateInitializer is
    ISuperDCAPoolV1_UV4StateInitializer
{
    uint24 private constant BASE_LP_FEE = 500; //0.05%
    int24 private constant MAX_TICK_SPACING = 60;

    Currency private superDCAToken;

    function isExistingPool(
        address poolManagerAddress,
        PoolKey calldata key
    ) public returns (bool _isExistingPool) {
        _isExistingPool = true
            ? IPoolManager(poolManagerAddress).initialize(key, uint160(0)) !=
                type(int24).max
            : false;
    }
    function areAllExistingPools(
        address poolManagerAddress,
        PoolKey[] calldata keys
    ) external returns (bool allExistingPools) {
        allExistingPools = true;
        for (uint256 keyIndex = 0; keyIndex < keys.length; keyIndex++) {
            if (!isExistingPool(poolManagerAddress, keys[keyIndex])) {
                allExistingPools = false;
            }
        }
    }

    function getPathKeys(
        Currency underlyingInputToken,
        Currency underlyingOutputToken
    )
        external
        view
        returns (PathKey[] memory swapPathKey, PathKey[] memory gasPathKey)
    {
        swapPathKey = new PathKey[](2);
        swapPathKey[0] = PathKey(
            superDCAToken,
            BASE_LP_FEE,
            MAX_TICK_SPACING,
            IHooks(address(0)),
            bytes("")
        );
        swapPathKey[1] = PathKey(
            underlyingOutputToken,
            BASE_LP_FEE,
            MAX_TICK_SPACING,
            IHooks(address(0)),
            bytes("")
        );
        gasPathKey = new PathKey[](1);
        gasPathKey[0] = PathKey(
            underlyingInputToken,
            BASE_LP_FEE,
            MAX_TICK_SPACING,
            IHooks(address(0)),
            bytes("")
        );
    }

    function safeMaxAllowance(
        address V4RouterAddr,
        Currency underlyingInputToken
    ) external {
        IERC20(Currency.unwrap(underlyingInputToken)).approve(
            V4RouterAddr,
            type(uint256).max
        );
    }
}
