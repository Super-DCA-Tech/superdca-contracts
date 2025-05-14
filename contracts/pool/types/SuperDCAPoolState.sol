// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.28;
pragma abicoder v2;

import {SSTORE2} from "solady/utils/SSTORE2.sol";

import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

import {IWETH} from "../../interface/IWETH.sol";

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";

import "../base/Constants.sol";
import "../base/Errors.sol";

import "../../SuperDCATrade.sol";
import {SuperDCAPoolStorage} from "../../SuperDCAPoolStorage.sol";

using SSTORE2 for address;

struct SuperDCAPoolState {
    SuperTokens superTokens;
    Tokens tokens;
    uint256 lastDistributedAt; // The timestamp of the last distribution
}

struct SuperTokens {
    ISuperToken inputToken;
    ISuperToken outputToken;
    ISuperToken wethx;
}

struct Tokens {
    IERC20 underlyingInputToken;
    IERC20 underlyingOutputToken;
    IWETH weth;
}

struct SuperDCAPoolStateRawPoolState {
    address immutableParamsPointer;
}

function getSuperDCAPoolStateParams(
    address ptr
) view returns (SuperDCAPoolState memory state) {
    bytes memory immutableParams = ptr.read();
    {
        ISuperToken inputToken;
        assembly {
            inputToken := shr(96, mload(add(immutableParams, 32)))
        }

        ISuperToken outputToken;
        assembly {
            outputToken := shr(96, mload(add(immutableParams, 52)))
        }

        ISuperToken wethx;
        assembly {
            wethx := shr(96, mload(add(immutableParams, 72)))
        }
        state.superTokens = SuperTokens({
            inputToken: inputToken,
            outputToken: outputToken,
            wethx: wethx
        });
    }
    {
        IERC20 underlyingInputToken;

        assembly {
            underlyingInputToken := shr(96, mload(add(immutableParams, 92)))
        }

        IERC20 underlyingOutputToken;

        assembly {
            underlyingOutputToken := shr(96, mload(add(immutableParams, 112)))
        }

        IWETH weth;

        assembly {
            weth := shr(96, mload(add(immutableParams, 132)))
        }

        state.tokens = Tokens({
            underlyingInputToken: underlyingInputToken,
            underlyingOutputToken: underlyingOutputToken,
            weth: weth
        });
    }
    {
        uint256 lastDistributedAt;

        assembly {
            lastDistributedAt := shr(96, mload(add(immutableParams, 164)))
        }

        state.lastDistributedAt = lastDistributedAt;
    }
}

function getSuperDCAPoolState(
    SuperDCAPoolStorage storage PoolStorage,
    PoolId poolId
) view returns (SuperDCAPoolState memory state) {
    SuperDCAPoolStateRawPoolState memory rawPoolState = PoolStorage.PoolState[
        poolId
    ];
    if (rawPoolState.immutableParamsPointer == address(0))
        revert PoolDoesNotExist();
    state = getSuperDCAPoolStateParams(rawPoolState.immutableParamsPointer);
}

function getDCAUSDCPoolKey() view returns (PoolKey memory DCA_USDC_KEY) {
    DCA_USDC_KEY = PoolKey({
        currency0: Currency.wrap(USDC_ADDRESS),
        currency1: Currency.wrap(DCA_ADDRESS),
        fee: 10_000,
        tickSpacing: 200,
        hooks: IHooks(address(0))
    });
}

function getDCAETHPoolKey() view returns (PoolKey memory DCA_ETH_KEY) {
    DCA_ETH_KEY = PoolKey({
        currency0: Currency.wrap(ETH_ADDRESS),
        currency1: Currency.wrap(DCA_ADDRESS),
        fee: 10_000,
        tickSpacing: 200,
        hooks: IHooks(address(0))
    });
}
