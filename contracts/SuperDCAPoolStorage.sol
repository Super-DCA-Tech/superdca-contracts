// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.28;

import "./pool/types/SuperDCAPoolState.sol";
import "./pool/base/Errors.sol";
import "v4-core/types/PoolId.sol";
import {SuperDCAPoolStateRawPoolState} from "./pool/types/SuperDCAPoolState.sol";

struct SuperDCAPoolStorage {
    mapping(PoolId poolId => SuperDCAPoolStateRawPoolState) PoolState;
}
