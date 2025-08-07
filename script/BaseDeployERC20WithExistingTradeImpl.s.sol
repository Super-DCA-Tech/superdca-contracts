// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseDeployERC20WithExistingTrade.sol";

contract BaseDeployERC20WithExistingTradeImpl is BaseDeployERC20WithExistingTrade {
  function run() public override returns (SuperDCAPoolV1, SuperDCATrade) {
    // Get existing SuperDCATrade address from environment or use default
    address existingTradeAddress = vm.envOr("EXISTING_TRADE_ADDRESS", address(0));
    
    if (existingTradeAddress != address(0)) {
      return runWithExistingTrade(existingTradeAddress);
    } else {
      return super.run(); // Fall back to creating new SuperDCATrade
    }
  }

  function getConfiguration() public pure override returns (NetworkConfiguration memory) {
    return NetworkConfiguration({
      // Superfluid
      hostSuperfluid: 0x4C073B3baB6d8826b8C5b229f3cfdC1eC6E47E74,
      idaSuperfluid: 0x66DF3f8e14CF870361378d8F61356D15d9F425C4,
      cfaSuperfluid: 0x19ba78B9cDB05A877718841c574325fdB53601bb,
      sfRegKey: "k1",
      // Tokens
      usdcx: 0xD04383398dD2426297da660F9CCA3d439AF9ce1b,
      wbtcx: 0x9D9DC5737C854b81bb7497097321adFf7d74Ce5C,
      // Uniswap V4
      universalRouter: 0x6fF5693b99212Da76ad316178A184AB56D299b43,
      poolManager: 0x498581fF718922c3f8e6A244956aF099B2652b2b,
      permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
      // Chainlink
      chainlinkBtcUsd: 0x64c911996D3c6aC71f9b455B1E8E7266BcbD848F,
      // Gelato
      gelatoAutomate: 0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0
    });
  }
}