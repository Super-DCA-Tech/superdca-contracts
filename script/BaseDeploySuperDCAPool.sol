// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../contracts/SuperDCAPoolV1.sol";
import "../contracts/SuperDCATrade.sol";
import {
  ISuperfluid,
  IConstantFlowAgreementV1,
  ISuperToken
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

abstract contract BaseDeploySuperDCAPool is Script {
  struct NetworkConfiguration {
    // Superfluid
    address sfResolver;
    address hostSuperfluid;
    address idaSuperfluid;
    address cfaSuperfluid;
    string sfRegKey;
    // Tokens
    address dcaToken;
    address usdcx;
    address usdc;
    address daix;
    address dai;
    address wethx;
    address weth;
    // Uniswap
    address uniswapV3Router;
    address uniswapV3Factory;
    uint24 uniswapPoolFee;
    // Chainlink
    address chainlinkEthUsdc;
    address chainlinkUsdcUsd;
    address chainlinkDaiUsd;
    // Gelato
    address gelatoOps;
    address gelatoNetwork;
    uint256 gelatoFee;
    // Deployment constants
    uint256 shareScaler;
    uint256 feeRate;
    uint256 affiliateFee;
    uint256 rateTolerance;
    uint256 initialPrice;
  }

  uint256 public deployerPrivateKey;

  function setUp() public virtual {
    deployerPrivateKey = vm.envUint("PRIVATE_KEY");
  }

  function getConfiguration() public virtual returns (NetworkConfiguration memory);

  function run() public virtual returns (SuperDCAPoolV1, SuperDCATrade) {
    vm.startBroadcast(deployerPrivateKey);

    // Set configuration explicitly in each network's deploy script
    NetworkConfiguration memory config = getConfiguration();

    // Deploy the pool
    SuperDCAPoolV1 pool = new SuperDCAPoolV1(payable(config.gelatoOps));

    // Setup initialization params
    address[] memory path = new address[](3);
    path[0] = config.usdc;
    path[1] = config.dcaToken;
    path[2] = config.weth;

    uint24[] memory fees = new uint24[](2);
    fees[0] = config.uniswapPoolFee;
    fees[1] = config.uniswapPoolFee;

    SuperDCAPoolV1.InitParams memory params = SuperDCAPoolV1.InitParams({
      host: ISuperfluid(config.hostSuperfluid),
      cfa: IConstantFlowAgreementV1(config.cfaSuperfluid),
      ida: IInstantDistributionAgreementV1(config.idaSuperfluid),
      weth: IWETH(config.weth),
      wethx: ISuperToken(config.wethx),
      inputToken: ISuperToken(config.usdcx),
      outputToken: ISuperToken(config.wethx),
      router: ISwapRouter02(config.uniswapV3Router),
      uniswapFactory: IUniswapV3Factory(config.uniswapV3Factory),
      uniswapPath: path,
      poolFees: fees,
      priceFeed: AggregatorV3Interface(config.chainlinkEthUsdc),
      invertPrice: false,
      registrationKey: config.sfRegKey,
      ops: payable(config.gelatoOps)
    });

    // Initialize the pool
    pool.initialize(params);

    return (pool, pool.dcaTrade());
  }
}
