// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.25;

import {IV4Router} from "v4-periphery/src/interfaces/IV4Router.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

struct InitParams {
    // =====SUPERLOW========
    // ISuperfluid host;
    // IConstantFlowAgreementV1 cfa;
    // IInstantDistributionAgreementV1 ida;
    // IWETH weth;
    // ISuperToken wethx;
    // ISuperToken inputToken;
    // ISuperToken outputToken;
    //=======UNISWAP========
    IV4Router router;
    IPoolManager poolManager;
    address[] uniswapPath;
    uint24[] poolFees;
    //=====CHANINLINK======
    // AggregatorV3Interface priceFeed;
    // bool invertPrice;
    //=====GELATO==========
    // string registrationKey;
    // address payable automate;
}
interface ISuperDCAPoolV1_UV4 {
    function initialize(InitParams memory params) external;
}
