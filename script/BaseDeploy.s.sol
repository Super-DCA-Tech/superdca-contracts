// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseDeploySuperDCAPool.sol";

contract BaseDeploy is BaseDeploySuperDCAPool {
  function run() public override returns (SuperDCAPoolV1, SuperDCATrade) {
    return super.run();
  }

  function getConfiguration() public pure override returns (NetworkConfiguration memory) {
    return NetworkConfiguration({
      // Superfluid
      sfResolver: 0x6a214c324553F96F04eFBDd66908685525Da0E0d,
      hostSuperfluid: 0x4C073B3baB6d8826b8C5b229f3cfdC1eC6E47E74,
      idaSuperfluid: 0x66DF3f8e14CF870361378d8F61356D15d9F425C4,
      cfaSuperfluid: 0x19ba78B9cDB05A877718841c574325fdB53601bb,
      sfRegKey: "k1",
      // Tokens
      dcaToken: 0xb1599CDE32181f48f89683d3C5Db5C5D2C7C93cc,
      usdcx: 0xD04383398dD2426297da660F9CCA3d439AF9ce1b,
      usdc: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
      wethx: 0x46fd5cfB4c12D87acD3a13e92BAa53240C661D93,
      weth: 0x4200000000000000000000000000000000000006,
      // Uniswap V4
      universalRouter: 0x6fF5693b99212Da76ad316178A184AB56D299b43,
      poolManager: 0x498581fF718922c3f8e6A244956aF099B2652b2b,
      permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
      // Chainlink
      chainlinkEthUsdc: 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70,
      chainlinkUsdcUsd: 0x0000000000000000000000000000000000000000,
      chainlinkDaiUsd: 0x0000000000000000000000000000000000000000,
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
