// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseDeploySuperDCAPool.sol";

contract OptimismDeploy is BaseDeploySuperDCAPool {
  function run() public override returns (SuperDCAPoolV1, SuperDCATrade) {
    return super.run();
  }

  function getConfiguration() public pure override returns (NetworkConfiguration memory) {
    return NetworkConfiguration({
      // Superfluid
      sfResolver: 0x743B5f46BC86caF41bE4956d9275721E0531B186,
      hostSuperfluid: 0x567c4B141ED61923967cA25Ef4906C8781069a10,
      idaSuperfluid: 0xc4ce5118C3B20950ee288f086cb7FC166d222D4c,
      cfaSuperfluid: 0x204C6f131bb7F258b2Ea1593f5309911d8E458eD,
      sfRegKey: "k1",
      // Tokens
      dcaToken: 0xb1599CDE32181f48f89683d3C5Db5C5D2C7C93cc,
      usdcx: 0x8430F084B939208E2eDEd1584889C9A66B90562f,
      usdc: 0x7F5c764cBc14f9669B88837ca1490cCa17c31607,
      daix: 0x7d342726B69C28D942ad8BfE6Ac81b972349d524,
      dai: 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1,
      wethx: 0x4ac8bD1bDaE47beeF2D1c6Aa62229509b962Aa0d,
      weth: 0x4200000000000000000000000000000000000006,
      // Uniswap V4
      universalRouter: 0x851116D9223fabED8E56C0E6b8Ad0c31d98B3507,
      poolManager: 0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3,
      permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
      // Chainlink
      chainlinkEthUsdc: 0x13e3Ee699D1909E989722E753853AE30b17e08c5,
      chainlinkUsdcUsd: 0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3,
      chainlinkDaiUsd: 0x8dBa75e83DA73cc766A7e5a0ee71F656BAb470d6,
      // Gelato
      gelatoAutomate: 0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0,
      gelatoNetwork: 0x01051113D81D7d6DA508462F2ad6d7fD96cF42Ef,
      gelatoFee: 0,
      // Deployment constants
      shareScaler: 10_000,
      feeRate: 50,
      affiliateFee: 5000,
      rateTolerance: 150,
      initialPrice: 0
    });
  }
}
