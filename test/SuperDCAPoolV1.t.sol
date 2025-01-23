// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

// Forge imports
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {SuperDCAPoolV1} from "../contracts/SuperDCAPoolV1.sol";
import {IWETH} from "../contracts/external/weth/IWETH.sol";
import {ISwapRouter02} from "../contracts/external/uniswap/ISwapRouter02.sol";
import {Ops} from "../contracts/external/gelato/Ops.sol";
import {ModuleData, Module} from "../contracts/external/gelato/Types.sol";
import {ICFAForwarder} from "./interfaces/ICFAForwarder.sol";
import {
  ISuperfluid,
  ISuperToken,
  ISuperAgreement
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {IConstantFlowAgreementV1} from
  "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {IInstantDistributionAgreementV1} from
  "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IInstantDistributionAgreementV1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {AggregatorV3Interface} from
  "@chainlink/contracts/interfaces/AggregatorV3Interface.sol";

contract SuperDCAPoolV1Test is Test {
  // Constants from optimism network
  address public constant HOST_SUPERFLUID = 0x567c4B141ED61923967cA25Ef4906C8781069a10;
  address public constant IDA_SUPERFLUID = 0xc4ce5118C3B20950ee288f086cb7FC166d222D4c;
  address public constant CFA_SUPERFLUID = 0x204C6f131bb7F258b2Ea1593f5309911d8E458eD;
  address public constant CFA_FORWARDER = 0xcfA132E353cB4E398080B9700609bb008eceB125;
  address public constant USDCX = 0x8430F084B939208E2eDEd1584889C9A66B90562f;
  address public constant USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
  address public constant WETHX = 0x4ac8bD1bDaE47beeF2D1c6Aa62229509b962Aa0d;
  address public constant WETH = 0x4200000000000000000000000000000000000006;
  address public constant DCA = 0xb1599CDE32181f48f89683d3C5Db5C5D2C7C93cc;
  address public constant UNISWAP_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
  address public constant UNISWAP_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
  address public constant ETH_USDC_FEED = 0x13e3Ee699D1909E989722E753853AE30b17e08c5;
  address public constant GELATO_OPS = 0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0;
  address public constant GELATO_NETWORK = 0x01051113D81D7d6DA508462F2ad6d7fD96cF42Ef;

  // Details need to deploy as an approved deployer for SF
  address public constant AUTHORIZED_DEPLOYER = 0x744f96332713EFC378e334A7eccAEc8E19532100;
  uint256 public constant FORK_BLOCK_NUMBER = 120_269_002;

  // Simulation constants
  uint256 public constant UPGRADE_AMOUNT = 1e18;
  uint256 public constant INFLOW_RATE_USDC = 1e12;

  // Pool and test accounts
  SuperDCAPoolV1 public pool;
  address public alice;
  address public bob;
  uint256 public gelatoBlockTimestamp;

  function _approveSubscription(address subscriber) internal {
    // Get the IDA interface
    IInstantDistributionAgreementV1 ida = IInstantDistributionAgreementV1(IDA_SUPERFLUID);

    // Encode the approval call
    bytes memory callData = abi.encodeWithSelector(
      ida.approveSubscription.selector,
      ISuperToken(WETHX),
      address(pool),
      0, // indexId
      new bytes(0)
    );

    // Call through the host
    vm.startPrank(subscriber);
    ISuperfluid(HOST_SUPERFLUID).callAgreement(
      ISuperAgreement(IDA_SUPERFLUID),
      callData,
      new bytes(0) // userData
    );
    vm.stopPrank();
  }

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl("optimism"), FORK_BLOCK_NUMBER);

    vm.startPrank(AUTHORIZED_DEPLOYER, AUTHORIZED_DEPLOYER);
    pool = new SuperDCAPoolV1(payable(GELATO_OPS));

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

    pool.initialize(params);
    gelatoBlockTimestamp = block.timestamp;

    vm.stopPrank();

    alice = makeAddr("alice");
    bob = makeAddr("bob");

    _dealAndUpgradeUSDCx(alice);
    _dealAndUpgradeUSDCx(bob);

    // Add subscription approvals
    _approveSubscription(alice);
    _approveSubscription(bob);
    _approveSubscription(address(this));
  }

  function _dealAndUpgradeUSDCx(address user) internal {
    deal(USDC, user, UPGRADE_AMOUNT);
    vm.startPrank(user);
    IERC20(USDC).approve(USDCX, type(uint256).max);
    ISuperToken(USDCX).upgrade(UPGRADE_AMOUNT);
    vm.stopPrank();
  }

  function _deleteFlow(address sender) internal {
    vm.prank(sender);
    ICFAForwarder(CFA_FORWARDER).deleteFlow(ISuperToken(USDCX), sender, address(pool), new bytes(0));
  }

  function _createFlow(address sender, uint96 flowRate) internal {
    vm.startPrank(sender);
    // Approve and upgrade USDC to USDCx
    IERC20(USDC).approve(USDCX, type(uint256).max);
    ISuperToken(USDCX).upgrade(UPGRADE_AMOUNT);

    // Create the stream
    ICFAForwarder(CFA_FORWARDER).createFlow(
      ISuperToken(USDCX), sender, address(pool), int96(flowRate), new bytes(0)
    );
    vm.stopPrank();
  }

  function testFork_PoolInitialization() public view {
    // Verify initialization
    assertEq(address(pool.inputToken()), USDCX);
    assertEq(address(pool.outputToken()), WETHX);
    assertEq(address(pool.weth()), WETH);
    assertEq(address(pool.wethx()), WETHX);
    assertEq(pool.gelatoFeeShare(), 1e16); // 1% default fee
  }

  function testFork_StreamersWithTheSameFlowRateGetTheSameDeal() public {
    _createFlow(alice, uint96(INFLOW_RATE_USDC));
    _createFlow(bob, uint96(INFLOW_RATE_USDC));

    skip(1 days);

    pool.distribute(new bytes(0), true);

    uint256 aliceBalance = ISuperToken(WETHX).balanceOf(alice);
    uint256 bobBalance = ISuperToken(WETHX).balanceOf(bob);

    // The both got WETHx
    assertGt(aliceBalance, 0);
    assertGt(bobBalance, 0);

    // The both got the same amount of WETHx
    assertEq(aliceBalance, bobBalance);
  }

  function testFork_GelatoDistribution() public {
    // Convert INFLOW_RATE_USDC to int96 safely
    int96 flowRate = int96(int256(INFLOW_RATE_USDC * 10));

    // Alice opens a USDC stream to SuperDCAPool with 10x flow rate to ensure Gelato can be paid
    vm.startPrank(alice);
    ICFAForwarder(CFA_FORWARDER).createFlow(
      ISuperToken(USDCX), alice, address(pool), flowRate, new bytes(0)
    );
    vm.stopPrank();

    // Take initial measurements
    uint256 aliceInitialBalance = ISuperToken(WETHX).balanceOf(alice);

    // Skip time and do first distribution
    skip(1 days);

    // Impersonate Gelato Network and set balance
    vm.deal(GELATO_NETWORK, 100 ether);
    vm.startPrank(GELATO_NETWORK);

    // Setup Gelato execution data
    bytes memory execData = abi.encodeWithSelector(pool.distribute.selector, new bytes(0), false);

    // Encode module data similar to TypeScript test
    ModuleData memory moduleData = ModuleData({modules: new Module[](2), args: new bytes[](2)});

    moduleData.modules[0] = Module.PROXY;
    moduleData.modules[1] = Module.TRIGGER;
    moduleData.args[0] = ""; // Empty bytes for PROXY module
    moduleData.args[1] = abi.encode(
      uint256(0), // First arg in TypeScript encoding
      abi.encode( // Second arg (encodedArgs) in TypeScript encoding
      uint128(gelatoBlockTimestamp), uint128(60_000))
    );

    // Execute through Gelato Ops
    Ops(GELATO_OPS).exec(
      address(pool),
      address(pool),
      execData,
      moduleData,
      1, // Gelato fee
      0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,
      false
    );
    vm.stopPrank();

    // Skip more time and do another distribution
    skip(1 days);

    // Execute second distribution through Gelato
    vm.startPrank(GELATO_NETWORK);
    Ops(GELATO_OPS).exec(
      address(pool),
      address(pool),
      execData,
      moduleData,
      1,
      0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,
      false
    );
    vm.stopPrank();

    // Check Alice's final balance
    uint256 aliceFinalBalance = ISuperToken(WETHX).balanceOf(alice);

    // Verify Alice received ETHx
    assertGt(aliceFinalBalance, aliceInitialBalance);

    // Get oracle price for comparison
    int256 oraclePrice = pool.getLatestPrice();

    // Calculate expected minimum output considering 2% slippage/fees
    uint256 inputAmount = uint256(int256(flowRate) * (2 days));
    uint256 minExpectedOutput = (inputAmount * 98) / (uint256(oraclePrice) * 100);

    // Verify Alice got at least the minimum expected amount
    assertGt(aliceFinalBalance - aliceInitialBalance, minExpectedOutput);

    // Clean up - close Alice's stream
    vm.startPrank(alice);
    ICFAForwarder(CFA_FORWARDER).deleteFlow(ISuperToken(USDCX), alice, address(pool), new bytes(0));
    vm.stopPrank();
  }
}
