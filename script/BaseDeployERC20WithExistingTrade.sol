// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseDeploySuperDCAPoolERC20.sol";

/// @title BaseDeployERC20WithExistingTrade
/// @notice Base ERC20 deployment script that can use an existing SuperDCATrade contract
abstract contract BaseDeployERC20WithExistingTrade is BaseDeploySuperDCAPoolERC20 {
  function runWithExistingTrade(address existingTradeAddress) public returns (SuperDCAPoolV1, SuperDCATrade) {
    vm.startBroadcast(deployerPrivateKey);

    // Set configuration explicitly in each network's deploy script
    NetworkConfiguration memory config = getConfiguration();

    // Deploy the pool with existing SuperDCATrade address
    SuperDCAPoolV1 pool = new SuperDCAPoolV1(
      payable(config.gelatoAutomate), config.universalRouter, config.poolManager, config.permit2, existingTradeAddress
    );

    SuperDCAPoolV1.InitParams memory params = SuperDCAPoolV1.InitParams({
      host: ISuperfluid(config.hostSuperfluid),
      cfa: IConstantFlowAgreementV1(config.cfaSuperfluid),
      ida: IInstantDistributionAgreementV1(config.idaSuperfluid),
      inputToken: ISuperToken(config.usdcx),
      outputToken: ISuperToken(config.wbtcx),
      priceFeed: AggregatorV3Interface(config.chainlinkBtcUsd),
      registrationKey: config.sfRegKey,
      automate: payable(config.gelatoAutomate)
    });

    // Initialize the pool with the correct params
    pool.initialize(params);

    vm.stopBroadcast();
    return (pool, pool.dcaTrade());
  }
}