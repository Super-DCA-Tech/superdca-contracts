// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {SuperDCASwap} from "../contracts/SuperDCASwap.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import {PathKey} from "@uniswap/v4-periphery/src/libraries/PathKey.sol";


/// @notice Test wrapper to expose internal methods
contract SuperDCASwapTestWrapper is SuperDCASwap {
  constructor(address _router, address _poolManager, address _permit2)
    SuperDCASwap(_router, _poolManager, _permit2)
  {}

  function approveTokenWithPermit2(address token, uint160 amount, uint48 expiration) external {
    _approveTokenWithPermit2(token, amount, expiration);
  }

  function swapExactInputSingle(
    PoolKey calldata key,
    bool zeroForOne,
    uint128 amountIn,
    uint128 minAmountOut
  ) external payable returns (uint256 amountOut) {
    return _swapExactInputSingle(key, zeroForOne, amountIn, minAmountOut);
  }

  function swapExactOutputSingle(
    PoolKey calldata key,
    bool zeroForOne,
    uint128 amountOut,
    uint128 maxAmountIn
  ) external payable returns (uint256 amountIn) {
    return _swapExactOutputSingle(key, zeroForOne, amountOut, maxAmountIn);
  }

  function swapExactInput(
    Currency currencyIn,
    PathKey[] memory path,
    uint128 amountIn,
    uint128 minAmountOut
  ) external payable returns (uint256 amountOut) {
    return _swapExactInput(currencyIn, path, amountIn, minAmountOut);
  }

  function swapExactOutput(
    Currency currencyOut,
    PathKey[] memory path,
    uint128 amountOut,
    uint128 maxAmountIn
  ) external payable returns (uint256 amountIn) {
    return _swapExactOutput(currencyOut, path, amountOut, maxAmountIn);
  }
}

contract SuperDCASwapTest is Test {
  // Uniswap V4 Optimism Mainnet addresses
  address constant UNIVERSAL_ROUTER = 0x851116D9223fabED8E56C0E6b8Ad0c31d98B3507;
  address constant POOL_MANAGER = 0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3;
  address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

  // Gauge hook address for DCA pool
  address constant GAUGE_HOOK_ADDRESS = 0xb4f4Ad63BCc0102B10e6227236e569Dce0d97A80;

  // Optimism token addresses
  address constant USDC_ADDRESS = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
  address constant WBTC_ADDRESS = 0x68f180fcCe6836688e9084f035309E29Bf0A2095;
  address constant DCA_ADDRESS = 0xb1599CDE32181f48f89683d3C5Db5C5D2C7C93cc;
  address constant ETH = address(0);

  IERC20 USDC = IERC20(USDC_ADDRESS);
  IERC20 WBTC = IERC20(WBTC_ADDRESS);
  IERC20 DCA = IERC20(DCA_ADDRESS);
  SuperDCASwapTestWrapper swapContract;

  // Pool keys for common pairs
  PoolKey ETH_USDC_KEY = PoolKey({
    currency0: Currency.wrap(ETH),
    currency1: Currency.wrap(USDC_ADDRESS),
    fee: 3000,
    tickSpacing: 60,
    hooks: IHooks(address(0))
  });

  PoolKey WBTC_USDC_KEY = PoolKey({
    currency0: Currency.wrap(USDC_ADDRESS),
    currency1: Currency.wrap(WBTC_ADDRESS),
    fee: 3000,
    tickSpacing: 60,
    hooks: IHooks(address(0))
  });

  PoolKey DCA_USDC_KEY = PoolKey({
    currency0: Currency.wrap(DCA_ADDRESS),
    currency1: Currency.wrap(USDC_ADDRESS),
    fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
    tickSpacing: 10,    
    hooks: IHooks(GAUGE_HOOK_ADDRESS)
  });

  PoolKey WBTC_DCA_KEY = PoolKey({
    currency0: Currency.wrap(WBTC_ADDRESS),
    currency1: Currency.wrap(DCA_ADDRESS),
    fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
    tickSpacing: 60,
    hooks: IHooks(GAUGE_HOOK_ADDRESS)
  });

  PoolKey ETH_DCA_KEY = PoolKey({
    currency0: Currency.wrap(ETH),
    currency1: Currency.wrap(DCA_ADDRESS),
    fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
    tickSpacing: 10,
    hooks: IHooks(GAUGE_HOOK_ADDRESS)
  });


  uint256 public constant FORK_BLOCK_NUMBER = 136_282_144; // May 25, 2025

  function setUp() public {
    // Fork Optimism mainnet    
    vm.selectFork(vm.createFork("https://mainnet.optimism.io", FORK_BLOCK_NUMBER));

    swapContract = new SuperDCASwapTestWrapper(UNIVERSAL_ROUTER, POOL_MANAGER, PERMIT2);

    vm.label(UNIVERSAL_ROUTER, "UNIVERSAL_ROUTER");
    vm.label(POOL_MANAGER, "POOL_MANAGER");
    vm.label(PERMIT2, "PERMIT2");
    vm.label(USDC_ADDRESS, "USDC");
    vm.label(WBTC_ADDRESS, "WBTC");
    vm.label(DCA_ADDRESS, "DCA");
  }

  function test_SwapExactInputSingle_ETH_For_USDC() public {
    uint128 amountIn = 1 ether; // 1 ETH
    uint128 minAmountOut = 0;

    // Fund test contract with ETH
    vm.deal(address(this), amountIn);

    // Execute swap (ETH -> USDC: zeroForOne = true)
    uint256 amountOut = swapContract.swapExactInputSingle{value: amountIn}(
      ETH_USDC_KEY,
      true, // zeroForOne
      amountIn,
      minAmountOut
    );

    // Verify swap results
    assertGt(amountOut, minAmountOut, "Swap failed: insufficient output amount");
    assertEq(address(swapContract).balance, 0, "ETH not fully spent");
    assertEq(USDC.balanceOf(address(swapContract)), amountOut, "USDC should be in contract");
  }

  function test_SwapExactInputSingle_USDC_For_WBTC() public {
    uint128 amountIn = 1000e6; // 1000 USDC
    uint128 minAmountOut = 0;

    // Fund contract with USDC and transfer to swap contract
    deal(USDC_ADDRESS, address(this), amountIn);
    USDC.transfer(address(swapContract), amountIn);

    // Approve tokens
    vm.prank(address(swapContract));
    swapContract.approveTokenWithPermit2(USDC_ADDRESS, amountIn, type(uint48).max);

    // Record initial WBTC balance
    uint256 initialWBTCBalance = WBTC.balanceOf(address(swapContract));

    // Execute swap (USDC -> WBTC)
    uint256 amountOut = swapContract.swapExactInputSingle(
      WBTC_USDC_KEY,
      true,
      amountIn,
      minAmountOut
    );

    // Verify swap results
    assertGt(amountOut, minAmountOut, "Swap failed: insufficient output amount");
    assertEq(USDC.balanceOf(address(swapContract)), 0, "USDC not fully spent");
    assertEq(WBTC.balanceOf(address(swapContract)) - initialWBTCBalance, amountOut, "WBTC not received correctly");
  }

  function test_SwapExactOutputSingle_USDC_For_WBTC() public {
    uint128 amountOut = 1e6; // Want exactly 0.01 WBTC (8 decimals)
    uint128 maxAmountIn = 10000e6; // Max 1000 USDC

    // Fund contract with USDC
    deal(USDC_ADDRESS, address(this), maxAmountIn);
    USDC.transfer(address(swapContract), maxAmountIn);

    // Approve tokens
    vm.prank(address(swapContract));
    swapContract.approveTokenWithPermit2(USDC_ADDRESS, maxAmountIn, uint48(block.timestamp + 1));

    // Record initial balances
    uint256 initialUSDCBalance = USDC.balanceOf(address(swapContract));
    uint256 initialWBTCBalance = WBTC.balanceOf(address(swapContract));

    // Execute exact output swap
    uint256 amountIn = swapContract.swapExactOutputSingle(
      WBTC_USDC_KEY,
      true,
      amountOut,
      maxAmountIn
    );

    // Verify swap results
    assertLe(amountIn, maxAmountIn, "Spent more than maximum allowed");
    assertGt(amountIn, 0, "Should have spent some USDC");
    assertEq(WBTC.balanceOf(address(swapContract)) - initialWBTCBalance, amountOut, "Should receive exact WBTC amount");
    assertEq(initialUSDCBalance - USDC.balanceOf(address(swapContract)), amountIn, "USDC spent should match return value");
  }

  function test_SwapExactInput_Multihop_USDC_To_DCA_Via_WBTC() public {
    uint128 amountIn = 1e6;
    uint128 minAmountOut = 1;

    // Define the swap path: USDC -> DCA -> WBTC
    PathKey[] memory path = new PathKey[](2);

    // Step 1: USDC -> DCA
    path[0] = PathKey({
      intermediateCurrency: Currency.wrap(DCA_ADDRESS),
      fee: DCA_USDC_KEY.fee,
      tickSpacing: DCA_USDC_KEY.tickSpacing,
      hooks: DCA_USDC_KEY.hooks,
      hookData: bytes("")
    });

    // Step 2: DCA -> WBTC
    path[1] = PathKey({
      intermediateCurrency: Currency.wrap(WBTC_ADDRESS),
      fee: WBTC_DCA_KEY.fee,
      tickSpacing: WBTC_DCA_KEY.tickSpacing,
      hooks: WBTC_DCA_KEY.hooks,
      hookData: bytes("")
    });

    Currency currencyIn = Currency.wrap(USDC_ADDRESS);

    // Fund contract with USDC
    deal(USDC_ADDRESS, address(this), amountIn);
    USDC.transfer(address(swapContract), amountIn);

    // Approve USDC spending
    vm.prank(address(swapContract));
    swapContract.approveTokenWithPermit2(USDC_ADDRESS, amountIn, uint48(block.timestamp + 1));

    // Execute multi-hop swap
    uint256 amountOut = swapContract.swapExactInput(currencyIn, path, amountIn, minAmountOut);

    // Verify swap results
    assertGt(amountOut, minAmountOut, "Swap failed: insufficient WBTC output");
    assertEq(USDC.balanceOf(address(swapContract)), 0, "USDC not fully spent");
    assertEq(WBTC.balanceOf(address(swapContract)), amountOut, "WBTC should be in contract");
  }

  function test_SwapExactOutput_Multihop_USDC_To_DCA_To_ETH() public {
    uint128 amountOut = 0.000001 ether; 
    uint128 maxAmountIn = 1e6; 

    // Define the swap path for an exact-output swap USDC -> DCA -> ETH
    // The router processes the path in reverse order, so the **last** array element
    // represents the **final hop** (DCA -> ETH) and its `intermediateCurrency` is
    // the token *before* the output (DCA). The preceding element then represents
    // the preceding hop (USDC -> DCA) with `intermediateCurrency` set to the
    // original input token (USDC).
    PathKey[] memory path = new PathKey[](2);

    // Final hop: DCA -> ETH (processed first by the router)
    path[1] = PathKey({
      intermediateCurrency: Currency.wrap(DCA_ADDRESS),
      fee: ETH_DCA_KEY.fee,
      tickSpacing: ETH_DCA_KEY.tickSpacing,
      hooks: ETH_DCA_KEY.hooks,
      hookData: bytes("")
    });

    // First hop: USDC -> DCA (processed second by the router)
    path[0] = PathKey({
      intermediateCurrency: Currency.wrap(USDC_ADDRESS),
      fee: DCA_USDC_KEY.fee,
      tickSpacing: DCA_USDC_KEY.tickSpacing,
      hooks: DCA_USDC_KEY.hooks,
      hookData: bytes("")
    });

    Currency currencyOut = Currency.wrap(ETH);

    // Fund contract with USDC tokens
    deal(USDC_ADDRESS, address(this), maxAmountIn);
    USDC.transfer(address(swapContract), maxAmountIn);

    // Approve USDC spending
    vm.prank(address(swapContract));
    swapContract.approveTokenWithPermit2(USDC_ADDRESS, maxAmountIn, type(uint48).max);

    // Record initial balances
    uint256 initialUSDCBalance = USDC.balanceOf(address(swapContract));
    uint256 initialETHBalance = address(swapContract).balance;

    // Execute exact output multi-hop swap
    uint256 amountIn = swapContract.swapExactOutput(currencyOut, path, amountOut, maxAmountIn);

    // Verify swap results
    assertLe(amountIn, maxAmountIn, "Spent more than maximum allowed");
    assertGt(amountIn, 0, "Should have spent some USDC");
    assertEq(address(swapContract).balance - initialETHBalance, amountOut, "Should receive exact ETH amount");
    assertEq(initialUSDCBalance - USDC.balanceOf(address(swapContract)), amountIn, "USDC spent should match return value");
  }

  function test_SwapExactOutputSingle_RevertIf_ExceedsMaxAmountIn() public {
    uint128 amountOut = 10 * 1e8; // Want large amount of WBTC (10 WBTC)
    uint128 maxAmountIn = 100e6; // Small max USDC (insufficient)

    // Fund contract
    deal(USDC_ADDRESS, address(this), 10000e6);
    USDC.transfer(address(swapContract), 10000e6);

    // Approve tokens
    vm.prank(address(swapContract));
    swapContract.approveTokenWithPermit2(USDC_ADDRESS, 10000e6, uint48(block.timestamp + 1));

    // Should revert because we need more than maxAmountIn
    vm.expectRevert();
    swapContract.swapExactOutputSingle(
      WBTC_USDC_KEY,
      true,  // USDC -> WBTC (currency0 -> currency1)
      amountOut,
      maxAmountIn
    );
  }

  function test_SwapExactInput_RevertIf_EmptyPath() public {
    PathKey[] memory emptyPath = new PathKey[](0);
    
    vm.expectRevert("Path cannot be empty");
    swapContract.swapExactInput(
      Currency.wrap(USDC_ADDRESS),
      emptyPath,
      1000e6,
      0
    );
  }

  function test_SwapExactOutput_RevertIf_EmptyPath() public {
    PathKey[] memory emptyPath = new PathKey[](0);
    
    vm.expectRevert("Path cannot be empty");
    swapContract.swapExactOutput(
      Currency.wrap(USDC_ADDRESS),
      emptyPath,
      1000e6,
      type(uint128).max
    );
  }

  receive() external payable {}
} 