// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {SuperDCAPoolV1} from "../contracts/SuperDCAPoolV1.sol";
import {
  ISuperfluid,
  ISuperToken
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {IConstantFlowAgreementV1} from
  "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {IInstantDistributionAgreementV1} from
  "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IInstantDistributionAgreementV1.sol";
import {IWETH} from "../contracts/external/weth/IWETH.sol";
import {ISwapRouter02} from "../contracts/external/uniswap/ISwapRouter02.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {AggregatorV3Interface} from
  "@chainlink/contracts/interfaces/AggregatorV3Interface.sol";

contract DeploySuperDCAPoolV1 is Script {
  // Constants from optimism network
  address public constant HOST_SUPERFLUID = 0x567c4B141ED61923967cA25Ef4906C8781069a10;
  address public constant IDA_SUPERFLUID = 0xc4ce5118C3B20950ee288f086cb7FC166d222D4c;
  address public constant CFA_SUPERFLUID = 0x204C6f131bb7F258b2Ea1593f5309911d8E458eD;
  address public constant USDCX = 0x8430F084B939208E2eDEd1584889C9A66B90562f;
  address public constant USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
  address public constant WETHX = 0x4ac8bD1bDaE47beeF2D1c6Aa62229509b962Aa0d;
  address public constant WETH = 0x4200000000000000000000000000000000000006;
  address public constant DCA = 0xb1599CDE32181f48f89683d3C5Db5C5D2C7C93cc;
  address public constant UNISWAP_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
  address public constant UNISWAP_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
  address public constant ETH_USDC_FEED = 0x13e3Ee699D1909E989722E753853AE30b17e08c5;
  address public constant GELATO_OPS = 0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0;

  function run() external {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    // Deploy the pool
    SuperDCAPoolV1 pool = new SuperDCAPoolV1(payable(GELATO_OPS));

    // Setup initialization params
    address[] memory path = new address[](3);
    path[0] = USDC;
    path[1] = DCA;
    path[2] = WETH;

    uint24[] memory fees = new uint24[](2);
    fees[0] = 500;
    fees[1] = 500;

    SuperDCAPoolV1.InitParams memory params = SuperDCAPoolV1.InitParams({
      host: ISuperfluid(HOST_SUPERFLUID),
      cfa: IConstantFlowAgreementV1(CFA_SUPERFLUID),
      ida: IInstantDistributionAgreementV1(IDA_SUPERFLUID),
      weth: IWETH(WETH),
      wethx: ISuperToken(WETHX),
      inputToken: ISuperToken(USDCX),
      outputToken: ISuperToken(WETHX),
      router: ISwapRouter02(UNISWAP_ROUTER),
      uniswapFactory: IUniswapV3Factory(UNISWAP_FACTORY),
      uniswapPath: path,
      poolFees: fees,
      priceFeed: AggregatorV3Interface(ETH_USDC_FEED),
      invertPrice: false,
      registrationKey: "k1",
      ops: payable(GELATO_OPS)
    });

    // Initialize the pool
    pool.initialize(params);

    vm.stopBroadcast();
  }
}
