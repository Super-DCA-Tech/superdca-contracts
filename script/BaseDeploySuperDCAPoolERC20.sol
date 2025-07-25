// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../contracts/SuperDCAPoolV1ERC20.sol";
import "../contracts/SuperDCATrade.sol";
import {
  ISuperfluid,
  IConstantFlowAgreementV1,
  ISuperToken
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {IInstantDistributionAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IInstantDistributionAgreementV1.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/interfaces/AggregatorV3Interface.sol";


abstract contract BaseDeploySuperDCAPoolERC20 is Script {
  struct NetworkConfiguration {
    // Superfluid
    address hostSuperfluid;
    address idaSuperfluid;
    address cfaSuperfluid;
    string sfRegKey;
    // Tokens
    address usdcx;
    address wbtcx;
    // Uniswap V4
    address universalRouter;
    address poolManager;
    address permit2;
    // Chainlink
    address chainlinkBtcUsd;
    // Gelato
    address gelatoAutomate;
  }

  uint256 public deployerPrivateKey;

  function setUp() public virtual {
    deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    console.log("Deployer address:", vm.addr(deployerPrivateKey));
  }

  function getConfiguration() public virtual returns (NetworkConfiguration memory);

  function run() public virtual returns (SuperDCAPoolV1, SuperDCATrade) {
    vm.startBroadcast(deployerPrivateKey);

    // Set configuration explicitly in each network's deploy script
    NetworkConfiguration memory config = getConfiguration();

    // Deploy the pool - pass the correct V4 addresses to constructor
    SuperDCAPoolV1 pool = new SuperDCAPoolV1(
      payable(config.gelatoAutomate), config.universalRouter, config.poolManager, config.permit2
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