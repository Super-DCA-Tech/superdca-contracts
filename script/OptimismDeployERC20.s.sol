// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseDeploySuperDCAPoolERC20.sol";

contract OptimismDeployERC20 is BaseDeploySuperDCAPoolERC20 {
  function run() public override returns (SuperDCAPoolV1, SuperDCATrade) {
    return super.run();
  }

  function getConfiguration() public pure override returns (NetworkConfiguration memory) {
    return NetworkConfiguration({
      // Superfluid
      hostSuperfluid: 0x567c4B141ED61923967cA25Ef4906C8781069a10,
      idaSuperfluid: 0xc4ce5118C3B20950ee288f086cb7FC166d222D4c,
      cfaSuperfluid: 0x204C6f131bb7F258b2Ea1593f5309911d8E458eD,
      sfRegKey: "k1",
      // Tokens
      usdcx: 0x35Adeb0638EB192755B6E52544650603Fe65A006,
      wbtcx: 0x9638EC1D29dfA9835fdb7fa74B5B77B14d6Ac77e,
      // Uniswap V4
      universalRouter: 0x851116D9223fabED8E56C0E6b8Ad0c31d98B3507,
      poolManager: 0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3,
      permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
      gaugeHookAddress: 0xBc5F29A583a8d3ec76e03372659e01a22feE3A80,
      usdcAddress: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
      dcaAddress: 0xb1599CDE32181f48f89683d3C5Db5C5D2C7C93cc,
      ethAddress: 0x0000000000000000000000000000000000000000,
      wbtcAddress: 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c,
      // Chainlink
      chainlinkBtcUsd: 0xD702DD976Fb76Fffc2D3963D037dfDae5b04E593,
      // Gelato
      gelatoAutomate: 0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0
    });
  }
} 