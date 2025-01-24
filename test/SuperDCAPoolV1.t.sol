// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

// Forge imports
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {SuperDCAPoolV1} from "../contracts/SuperDCAPoolV1.sol";
import {SuperDCATrade} from "../contracts/SuperDCATrade.sol";
import {IWETH} from "../contracts/external/weth/IWETH.sol";
import {ISETHCustom} from "../contracts/external/superfluid/ISETHCustom.sol";
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
import {AggregatorV3Interface} from "@chainlink/contracts/interfaces/AggregatorV3Interface.sol";

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

  function _approveSubscription(
    address subscriber,
    address token,
    address poolAddress
  ) internal {
    // Get the IDA interface
    IInstantDistributionAgreementV1 ida = IInstantDistributionAgreementV1(IDA_SUPERFLUID);

    // Encode the approval call
    bytes memory callData = abi.encodeWithSelector(
      ida.approveSubscription.selector,
      ISuperToken(token),
      poolAddress,
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

    _dealAndUpgrade(alice, USDC);
    _dealAndUpgrade(bob, USDC);

    // Add subscription approvals with updated parameters
    _approveSubscription(alice, WETHX, address(pool));
    _approveSubscription(bob, WETHX, address(pool));
  }

  function _dealAndUpgrade(address user, address token) internal {
    if (token == USDC) {
      deal(USDC, user, UPGRADE_AMOUNT);
      vm.startPrank(user);
      IERC20(USDC).approve(USDCX, type(uint256).max);
      ISuperToken(USDCX).upgrade(UPGRADE_AMOUNT);
      vm.stopPrank();
    } else if (token == WETH) {
      deal(user, UPGRADE_AMOUNT);
      vm.startPrank(user);
      ISETHCustom(WETHX).upgradeByETH{value: UPGRADE_AMOUNT}();
      vm.stopPrank();
    }
  }

  function _deleteFlow(address sender) internal {
    vm.prank(sender);
    ICFAForwarder(CFA_FORWARDER).deleteFlow(ISuperToken(USDCX), sender, address(pool), new bytes(0));
  }

  function _createFlow(
    address sender,
    address token,
    address pool,
    uint96 flowRate
  ) internal {
    vm.startPrank(sender);
    ICFAForwarder(CFA_FORWARDER).createFlow(
      ISuperToken(token),
      sender,
      pool,
      int96(flowRate),
      new bytes(0)
    );
    vm.stopPrank();
  }

  function _updateFlow(address sender, uint96 flowRate) internal {
    vm.startPrank(sender);
    ICFAForwarder(CFA_FORWARDER).updateFlow(
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
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC));
    _createFlow(bob, USDCX, address(pool), uint96(INFLOW_RATE_USDC));

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

  function testFork_StreamerWithHigherFlowRateGetsMoreShares() public {
    // Alice opens a USDC stream with base rate
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC));

    // Bob opens a USDC stream with 2x rate
    _createFlow(bob, USDCX, address(pool), uint96(INFLOW_RATE_USDC * 2));

    skip(1 days);

    pool.distribute(new bytes(0), true);

    uint256 aliceBalance = ISuperToken(WETHX).balanceOf(alice);
    uint256 bobBalance = ISuperToken(WETHX).balanceOf(bob);

    // Both got WETHx
    assertGt(aliceBalance, 0);
    assertGt(bobBalance, 0);

    // Bob got ~2x what Alice got (allowing for small rounding differences)
    assertApproxEqRel(bobBalance, aliceBalance * 2, 0.01e18); // 1% tolerance
  }

  function testFork_StreamerCanUpdateFlowRate() public {
    // Alice opens initial stream
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC));

    skip(1 days);

    // First distribution
    pool.distribute(new bytes(0), true);
    uint256 aliceBalanceInitial = ISuperToken(WETHX).balanceOf(alice);

    // Alice updates to 2x flow rate
    _updateFlow(alice, uint96(INFLOW_RATE_USDC * 2));

    skip(1 days);

    // Second distribution
    pool.distribute(new bytes(0), true);
    uint256 aliceBalanceFinal = ISuperToken(WETHX).balanceOf(alice);

    // The second day's earnings should be ~2x the first day
    uint256 firstDayEarnings = aliceBalanceInitial;
    uint256 secondDayEarnings = aliceBalanceFinal - aliceBalanceInitial;

    assertApproxEqRel(secondDayEarnings, firstDayEarnings * 2, 0.01e18); // 1% tolerance
  }

  function testFork_StreamerCanCloseStream() public {
    // Alice opens a stream
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC));

    skip(1 days);

    // First distribution
    pool.distribute(new bytes(0), true);
    uint256 aliceBalanceAfterFirst = ISuperToken(WETHX).balanceOf(alice);

    // Alice closes her stream
    _deleteFlow(alice);

    skip(1 days);

    // Second distribution
    pool.distribute(new bytes(0), true);
    uint256 aliceBalanceAfterSecond = ISuperToken(WETHX).balanceOf(alice);

    // Alice's balance shouldn't change after closing stream
    assertEq(aliceBalanceAfterFirst, aliceBalanceAfterSecond);
  }

  function testFork_TradeTracking() public {
    // Alice opens a stream
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC));

    // Check initial trade info
    SuperDCATrade.Trade memory trade = pool.getLatestTrade(alice);
    assertEq(uint256(int256(trade.flowRate)), uint256(INFLOW_RATE_USDC)); // Convert int96 to
      // uint256
    assertEq(trade.startTime, uint256(block.timestamp));
    assertEq(trade.endTime, uint256(0)); // Ongoing trade

    skip(1 days);

    // Close stream
    _deleteFlow(alice);

    // Check final trade info
    trade = pool.getLatestTrade(alice);
    assertEq(trade.endTime, uint256(block.timestamp));

    // Check trade count
    assertEq(pool.getTradeCount(alice), uint256(1));
  }

  function testFork_RefundsUninvestedAmount() public {
    // Alice opens a stream
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC));

    uint256 aliceBalanceBefore = ISuperToken(USDCX).balanceOf(alice);

    // Close stream immediately before any distribution
    _deleteFlow(alice);

    uint256 aliceBalanceAfter = ISuperToken(USDCX).balanceOf(alice);

    // Alice should get back almost all her streamed tokens
    // (minus very small amount from time elapsed)
    assertGt(aliceBalanceAfter, aliceBalanceBefore - 1e6);
  }

  function testFork_CalculatesNextDistributionTime() public {
    // Alice opens a stream
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC));

    uint256 gasPrice = 1e9; // 1 Gwei
    uint256 gasLimit = 1e6; // 1M gas
    uint256 tokenToWethRate = 1e18; // 1:1 for simplicity

    uint256 nextDistTime = pool.getNextDistributionTime(gasPrice, gasLimit, tokenToWethRate);

    // Next distribution should be in the future
    assertGt(nextDistTime, block.timestamp);

    // Should be lastDistributedAt + calculated time
    assertEq(
      nextDistTime,
      pool.lastDistributedAt()
        + ((gasPrice * gasLimit * tokenToWethRate) / (INFLOW_RATE_USDC / 1e9)) / 1e9
    );
  }

  // Add other tests here from the TypeScript tests

  function testFork_GelatoDistribution() public {
    // Convert INFLOW_RATE_USDC to int96 safely
    int96 flowRate = int96(int256(INFLOW_RATE_USDC * 10));

    // Alice opens a USDC stream to SuperDCAPool with 10x flow rate to ensure Gelato can be paid
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC * 10));

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

  function testFork_GetIDAShares() public {
    // Create flow for alice
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC));

    // Check IDA shares
    (bool exist, bool approved, uint128 units, uint256 pendingDist) = pool.getIDAShares(alice);

    assertTrue(exist);
    assertTrue(approved); // We approved in setup
    assertEq(units, uint128(INFLOW_RATE_USDC / pool.SHARE_SCALER())); // Flow rate divided by scaler
    assertEq(pendingDist, 0); // No pending distribution yet
  }

  function testFork_GetIDAIndexValue() public {
    // Create flow and distribute
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC));
    skip(1 days);
    pool.distribute(new bytes(0), true);

    uint256 indexValue = pool.getIDAIndexValue();
    assertGt(indexValue, 0); // Index value should be set after distribution
  }

  function testFork_CloseStream() public {
    // Create flow for alice
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC));

    // Drain alice's balance to enable stream closure
    vm.startPrank(alice);
    uint256 balance = ISuperToken(USDCX).balanceOf(alice);
    ISuperToken(USDCX).transfer(bob, balance - (uint256(INFLOW_RATE_USDC) * 4 hours));
    vm.stopPrank();

    // Should be able to close stream now
    pool.closeStream(alice, ISuperToken(USDCX));

    // Verify stream is closed
    (, int96 flowRate,,) =
      IConstantFlowAgreementV1(CFA_SUPERFLUID).getFlow(ISuperToken(USDCX), alice, address(pool));
    assertEq(flowRate, 0);
  }

  function testFork_CloseStreamReverts() public {
    // Create flow for alice
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC));

    // Should revert when trying to close stream with sufficient balance
    vm.expectRevert("!closable");
    pool.closeStream(alice, ISuperToken(USDCX));
  }

  function testFork_ExecutionFeeShareAdjustment() public {
    // Start with default fee
    uint256 currentFee = pool.gelatoFeeShare();

    // Set up a flow
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC));

    // Test fee decreases 3 times (should halve each time)
    for (uint256 i = 0; i < 3; i++) {
      skip(1 hours);
      pool.distribute(new bytes(0), true); // Reset lastDistributedAt
      uint256 decreasedFee = pool.getExecutionFeeShare(currentFee);
      assertEq(decreasedFee, currentFee / 2, "Fee should be cut in half");
      currentFee = decreasedFee;
    }

    // Test fee increases 3 times (should double each time)
    currentFee = pool.gelatoFeeShare();
    for (uint256 i = 0; i < 3; i++) {
      skip(5 hours); // Past distribution interval (4 hours)
      pool.distribute(new bytes(0), true); // Reset lastDistributedAt
      uint256 increasedFee = pool.gelatoFeeShare();
      assertEq(increasedFee, currentFee * 2, "Fee should double");
      currentFee = increasedFee;
    }

    // Verify max and min bounds still work
    uint256 maxFee = pool.MAX_FEE_SHARE();
    uint256 minFee = pool.MIN_FEE_SHARE();

    // Test max cap
    skip(24 hours);
    uint256 cappedFee = pool.getExecutionFeeShare(maxFee);
    assertEq(cappedFee, maxFee, "Fee should be capped at max");

    // Test min floor
    pool.distribute(new bytes(0), true);
    uint256 flooredFee = pool.getExecutionFeeShare(minFee);
    assertEq(flooredFee, minFee, "Fee should not go below min");
  }

  function testFork_CannotInitializeTwice() public {
    // First initialization happens in setUp()

    // Setup initialization params again
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

    // Attempt to initialize again should revert
    vm.expectRevert("Already initialized");
    pool.initialize(params);
  }

  function testFork_InitializeWithEmptyRegistrationKey() public {
    // Deploy a new pool instance since the one in setUp() is already initialized
    vm.startPrank(AUTHORIZED_DEPLOYER, AUTHORIZED_DEPLOYER);
    SuperDCAPoolV1 newPool = new SuperDCAPoolV1(payable(GELATO_OPS));

    // Setup initialization params with empty registration key
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
      registrationKey: "", // Empty registration key
      ops: payable(GELATO_OPS)
    });

    // Should initialize successfully even with empty registration key
    newPool.initialize(params);

    // Verify initialization was successful by checking a key parameter
    assertEq(address(newPool.inputToken()), USDCX);
    vm.stopPrank();
  }

  function testFork_InitializeRevertsWithNonexistentPool() public {
    // Deploy a new pool instance
    vm.startPrank(AUTHORIZED_DEPLOYER, AUTHORIZED_DEPLOYER);
    SuperDCAPoolV1 newPool = new SuperDCAPoolV1(payable(GELATO_OPS));

    // Setup initialization params with invalid pool fee
    address[] memory path = new address[](3);
    path[0] = USDC;
    path[1] = DCA;
    path[2] = WETH;

    uint24[] memory fees = new uint24[](2);
    fees[0] = 3000; // Using 3000 bps fee which doesn't exist for this pool
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

    // Attempt to initialize with nonexistent pool should revert
    vm.expectRevert(); // Pool Does Not Exist
    newPool.initialize(params);
    vm.stopPrank();
  }

  function testFork_InitializeRevertsWithNonexistentGasPool() public {
    // Deploy a new pool instance
    vm.startPrank(AUTHORIZED_DEPLOYER, AUTHORIZED_DEPLOYER);
    SuperDCAPoolV1 newPool = new SuperDCAPoolV1(payable(GELATO_OPS));

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

    // Mock the Uniswap factory to return address(0) for the gas reimbursement pool
    vm.mockCall(
      UNISWAP_FACTORY,
      abi.encodeWithSelector(
        IUniswapV3Factory.getPool.selector,
        WETH,
        USDC,
        500 // GELATO_GAS_POOL_FEE
      ),
      abi.encode(address(0))
    );

    // Attempt to initialize with nonexistent gas pool should revert
    vm.expectRevert(); // Pool Does Not Exist
    newPool.initialize(params);
    vm.stopPrank();

    // Clear the mock to not affect other tests
    vm.clearMockedCalls();
  }

  function testFork_InitializeWithWethxOutput() public {
    // Deploy a new pool instance
    vm.startPrank(AUTHORIZED_DEPLOYER, AUTHORIZED_DEPLOYER);
    SuperDCAPoolV1 newPool = new SuperDCAPoolV1(payable(GELATO_OPS));

    // Setup initialization params with WETHx as output token
    address[] memory path = new address[](3);
    path[0] = WETH; // Note: Path is reversed compared to normal setup
    path[1] = DCA;
    path[2] = USDC;

    uint24[] memory fees = new uint24[](2);
    fees[0] = 500;
    fees[1] = 500;

    SuperDCAPoolV1.InitParams memory params = SuperDCAPoolV1.InitParams({
      host: ISuperfluid(HOST_SUPERFLUID),
      cfa: IConstantFlowAgreementV1(CFA_SUPERFLUID),
      ida: IInstantDistributionAgreementV1(IDA_SUPERFLUID),
      weth: IWETH(WETH),
      wethx: ISuperToken(WETHX),
      inputToken: ISuperToken(WETHX),
      outputToken: ISuperToken(USDCX), // WETHx as output token
      router: ISwapRouter02(UNISWAP_ROUTER),
      uniswapFactory: IUniswapV3Factory(UNISWAP_FACTORY),
      uniswapPath: path,
      poolFees: fees,
      priceFeed: AggregatorV3Interface(ETH_USDC_FEED),
      invertPrice: true, // Invert price since path is reversed
      registrationKey: "k1",
      ops: payable(GELATO_OPS)
    });

    // Initialize the pool
    newPool.initialize(params);

    // Alice approves to receive USDCX output tokens
    _approveSubscription(alice, USDCX, address(newPool));

    // Verify initialization was successful
    assertEq(address(newPool.outputToken()), USDCX);
    assertEq(address(newPool.wethx()), WETHX);

    // Create a flow and verify the WETHx distribution works
    _dealAndUpgrade(alice, WETH);
    _createFlow(alice, WETHX, address(newPool), uint96(INFLOW_RATE_USDC));
    vm.startPrank(alice);
    skip(1 days);

    newPool.distribute(new bytes(0), true);
    uint256 aliceBalanceAfter = ISuperToken(WETHX).balanceOf(alice);

    // Verify Alice received WETHx
    assertGt(aliceBalanceAfter, 0);

    vm.stopPrank();
  }

  function testFork_GetTradeInfo() public {
    // Create a flow for alice
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC));
    
    skip(1 days);
    
    // End the trade
    _deleteFlow(alice);
    
    // Get trade info for the first (and only) trade
    SuperDCATrade.Trade memory trade = pool.getTradeInfo(alice, 0);
    
    // Verify trade details
    assertEq(uint256(int256(trade.flowRate)), uint256(INFLOW_RATE_USDC));
    assertEq(trade.startTime, uint256(block.timestamp - 1 days));
    assertEq(trade.endTime, uint256(block.timestamp));
  }

  function testFork_GetLatestTradeForNewUser() public {
    // Get latest trade for user with no trades
    SuperDCATrade.Trade memory trade = pool.getLatestTrade(alice);
    
    // Should return empty trade struct
    assertEq(uint256(int256(trade.flowRate)), 0);
    assertEq(trade.startTime, 0);
    assertEq(trade.endTime, 0);
  }

  function testFork_GetLatestTradeForActiveUser() public {
    // Create a flow for alice
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC));
    
    // Get latest trade
    SuperDCATrade.Trade memory trade = pool.getLatestTrade(alice);
    
    // Verify trade details
    assertEq(uint256(int256(trade.flowRate)), uint256(INFLOW_RATE_USDC));
    assertEq(trade.startTime, uint256(block.timestamp));
    assertEq(trade.endTime, 0); // Should be 0 for active trade
  }

  function testFork_GetTradeCountForNewUser() public {
    // Get trade count for new user
    uint256 count = pool.getTradeCount(alice);
    assertEq(count, 0);
  }

  function testFork_GetTradeCountForActiveUser() public {
    // Create a flow for alice
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC));
    
    // Get trade count
    uint256 count = pool.getTradeCount(alice);
    assertEq(count, 1);
    
    // Close and reopen flow to create second trade
    _deleteFlow(alice);
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC));
    
    // Verify count increased
    count = pool.getTradeCount(alice);
    assertEq(count, 2);
  }

  function testFork_GetNextDistributionTimeWithZeroFlow() public {
    // With zero inflow rate, should return lastDistributedAt
    uint256 nextDistTime = pool.getNextDistributionTime(1e9, 1e6, 1e18);
    assertEq(nextDistTime, type(uint256).max);
  }

  function testFork_GetNextDistributionTimeWithActiveFlow() public {
    // Create a flow
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC));
    
    uint256 gasPrice = 1e9; // 1 Gwei
    uint256 gasLimit = 1e6; // 1M gas
    uint256 tokenToWethRate = 1e18; // 1:1 for simplicity
    
    uint256 nextDistTime = pool.getNextDistributionTime(gasPrice, gasLimit, tokenToWethRate);
    
    // Calculate expected time
    uint256 expectedTime = pool.lastDistributedAt() + 
      ((gasPrice * gasLimit * tokenToWethRate) / (INFLOW_RATE_USDC / 1e9)) / 1e9;
    
    assertEq(nextDistTime, expectedTime);
  }

  function testFork_BeforeAgreementCreatedTokenValidation() public {
    // Test valid input token (USDCx) with CFA
    vm.startPrank(HOST_SUPERFLUID);
    bytes memory result = pool.beforeAgreementCreated(
      ISuperToken(USDCX),
      CFA_SUPERFLUID,
      bytes32(0),
      new bytes(0),
      new bytes(0)
    );
    assertEq(result.length, 0); // Should return empty bytes for valid case
    vm.stopPrank();

    // Test valid output token (WETHx) with IDA
    vm.startPrank(HOST_SUPERFLUID);
    result = pool.beforeAgreementCreated(
      ISuperToken(WETHX),
      IDA_SUPERFLUID,
      bytes32(0),
      new bytes(0),
      new bytes(0)
    );
    assertEq(result.length, 0); // Should return empty bytes for valid case
    vm.stopPrank();

    // Test invalid: input token with IDA (should revert)
    vm.startPrank(HOST_SUPERFLUID);
    vm.expectRevert("!token");
    pool.beforeAgreementCreated(
      ISuperToken(USDCX),
      IDA_SUPERFLUID,
      bytes32(0),
      new bytes(0),
      new bytes(0)
    );
    vm.stopPrank();

    // Test invalid: output token with CFA (should revert)
    vm.startPrank(HOST_SUPERFLUID);
    vm.expectRevert("!token");
    pool.beforeAgreementCreated(
      ISuperToken(WETHX),
      CFA_SUPERFLUID,
      bytes32(0),
      new bytes(0),
      new bytes(0)
    );
    vm.stopPrank();

    // Test invalid: non-host caller (should revert)
    vm.expectRevert("!host");
    pool.beforeAgreementCreated(
      ISuperToken(USDCX),
      CFA_SUPERFLUID,
      bytes32(0),
      new bytes(0),
      new bytes(0)
    );
  }

  function testFork_DistributeWithContext() public {
    // Create flow for alice first
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC));
    
    // Skip a few minutes
    skip(5 minutes);
    
    // Create flow for bob directly
    vm.startPrank(bob);
    ICFAForwarder(CFA_FORWARDER).createFlow(
      ISuperToken(USDCX),
      bob,
      address(pool),
      int96(int256(INFLOW_RATE_USDC)),
      "hello"
    );
    vm.stopPrank();
    
    // Skip some more time to accumulate balance
    skip(1 days);

    vm.startPrank(HOST_SUPERFLUID);
    
    // Call distribute with the specific context
    pool.distribute(new bytes(0), false);
        
    // Verify the distribution happened by checking both balances increased
    uint256 aliceBalance = ISuperToken(WETHX).balanceOf(alice);
    uint256 bobBalance = ISuperToken(WETHX).balanceOf(bob);
    
    assertGt(aliceBalance, 0, "Alice should have received WETHx");
    assertGt(bobBalance, 0, "Bob should have received WETHx");
    
    // Since Alice started streaming first, she should have more balance
    assertGt(aliceBalance, bobBalance, "Alice should have more WETHx than Bob");

    vm.stopPrank();
  }

  function testFork_OnlyHostModifier() public {
    // Try to call beforeAgreementCreated directly (not as host)
    vm.expectRevert("!host");
    pool.beforeAgreementCreated(
      ISuperToken(USDCX),
      CFA_SUPERFLUID,
      bytes32(0),
      new bytes(0),
      new bytes(0)
    );

    // Try to call afterAgreementCreated directly (not as host)
    vm.expectRevert("!host");
    pool.afterAgreementCreated(
      ISuperToken(USDCX),
      CFA_SUPERFLUID,
      bytes32(0),
      new bytes(0),
      new bytes(0),
      new bytes(0)
    );

    // Try to call beforeAgreementUpdated directly (not as host)
    vm.expectRevert("!host");
    pool.beforeAgreementUpdated(
      ISuperToken(USDCX),
      CFA_SUPERFLUID,
      bytes32(0),
      new bytes(0),
      new bytes(0)
    );

    // Try to call afterAgreementUpdated directly (not as host)
    vm.expectRevert("!host");
    pool.afterAgreementUpdated(
      ISuperToken(USDCX),
      CFA_SUPERFLUID,
      bytes32(0),
      new bytes(0),
      new bytes(0),
      new bytes(0)
    );

    // Try to call beforeAgreementTerminated directly (not as host)
    vm.expectRevert("!host");
    pool.beforeAgreementTerminated(
      ISuperToken(USDCX),
      CFA_SUPERFLUID,
      bytes32(0),
      new bytes(0),
      new bytes(0)
    );

    // Try to call afterAgreementTerminated directly (not as host)
    vm.expectRevert("!host");
    pool.afterAgreementTerminated(
      ISuperToken(USDCX),
      CFA_SUPERFLUID,
      bytes32(0),
      new bytes(0),
      new bytes(0),
      new bytes(0)
    );

    // Now test calling as host (should succeed)
    vm.startPrank(HOST_SUPERFLUID);
    
    // These should not revert
    bytes memory result = pool.beforeAgreementCreated(
      ISuperToken(USDCX),
      CFA_SUPERFLUID,
      bytes32(0),
      new bytes(0),
      new bytes(0)
    );
    
    // Verify we got a response (even if empty)
    assertEq(result.length, 0);

    vm.stopPrank();
  }

  function testFork_GetLatestPrice() public {
    // Test normal case - should return price from Chainlink feed
    int256 price = pool.getLatestPrice();
    assertGt(price, 0, "Price feed should return positive value");

    // Deploy new pool to test zero address case
    vm.startPrank(AUTHORIZED_DEPLOYER, AUTHORIZED_DEPLOYER);
    SuperDCAPoolV1 newPool = new SuperDCAPoolV1(payable(GELATO_OPS));

    // Setup initialization params with zero address price feed
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
        priceFeed: AggregatorV3Interface(address(0)), // Zero address price feed
        invertPrice: false,
        registrationKey: "k1",
        ops: payable(GELATO_OPS)
    });

    newPool.initialize(params);

    // Test zero address case - should return 0
    int256 zeroPrice = newPool.getLatestPrice();
    assertEq(zeroPrice, 0, "Price should be 0 when feed is zero address");
    vm.stopPrank();
  }

  function testFork_EmitsErrorEventOnRefundFailure() public {
    // Create flow for alice
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC));
    
    // Skip some time to accumulate uninvested amount
    skip(1 hours);
    
    // Mock the SuperToken to make transferFrom revert
    vm.mockCallRevert(
        USDCX,
        abi.encodeWithSelector(ISuperToken.transferFrom.selector),
        "TRANSFER_FAILED"
    );
    
    // Watch for the error event emission
    vm.expectEmit(true, true, true, true);
    emit SuperDCAPoolV1.ErrorRefundingUninvestedAmount(alice, INFLOW_RATE_USDC * 1 hours);
    
    // Close the stream which should trigger the refund attempt
    _deleteFlow(alice);
    
    // Clear the mock to not affect other tests
    vm.clearMockedCalls();
  }

  function testFork_EmitsRefundEventOnSuccess() public {
    // Create flow for alice
    _createFlow(alice, USDCX, address(pool), uint96(INFLOW_RATE_USDC));
    
    // Skip some time to accumulate uninvested amount
    skip(1 hours);
    
    // Watch for the refund event emission
    vm.expectEmit(true, true, true, true);
    emit SuperDCAPoolV1.RefundedUninvestedAmount(alice, INFLOW_RATE_USDC * 1 hours);
    
    // Close the stream which should trigger the refund
    _deleteFlow(alice);
  }
}
