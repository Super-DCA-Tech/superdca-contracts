// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @dev Imported from Super-DCA-Tech/super-dca-swap. I could not get the tests running in this repo
/// so the tests for this are located in the Super-DCA-Tech/super-dca-swap repo.
/// @notice Issues with importing the universal router solved with these imports
/// see: https://github.com/0ximmeas/univ4-swap-walkthrough
import {IUniversalRouter} from "./external/IUniversalRouter.sol";
import {Commands} from "./external/Commands.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PathKey} from "@uniswap/v4-periphery/src/libraries/PathKey.sol";
import {console} from "forge-std/console.sol";

contract SuperDCASwap {
  using StateLibrary for IPoolManager;

  IUniversalRouter public immutable ROUTER;
  IPoolManager public immutable POOL_MANAGER;
  IPermit2 public immutable PERMIT2;

  constructor(address _router, address _poolManager, address _permit2) {
    ROUTER = IUniversalRouter(_router);
    POOL_MANAGER = IPoolManager(_poolManager);
    PERMIT2 = IPermit2(_permit2);
  }

  function _approveTokenWithPermit2(address token, uint160 amount, uint48 expiration) internal {
    IERC20(token).approve(address(PERMIT2), type(uint256).max);
    PERMIT2.approve(token, address(ROUTER), amount, expiration);
  }

  function swapExactInputSingle(
    PoolKey calldata key,
    bool zeroForOne,
    uint128 amountIn,
    uint128 minAmountOut
  ) external payable returns (uint256 amountOut) {
    // Encode the Universal Router command
    bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
    bytes[] memory inputs = new bytes[](1);

    // Encode V4Router actions
    bytes memory actions = abi.encodePacked(
      uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL)
    );

    // Determine the actual input and output tokens based on zeroForOne
    Currency inputCurrency = zeroForOne ? key.currency0 : key.currency1;
    Currency outputCurrency = zeroForOne ? key.currency1 : key.currency0;
    address inputTokenAddress = Currency.unwrap(inputCurrency);
    address outputTokenAddress = Currency.unwrap(outputCurrency);

    bool requireETHValue = inputTokenAddress == address(0);

    // Prepare parameters for each action
    bytes[] memory params = new bytes[](3);
    params[0] = abi.encode(
      IV4Router.ExactInputSingleParams({
        poolKey: key,
        zeroForOne: zeroForOne,
        amountIn: amountIn,
        amountOutMinimum: minAmountOut,
        hookData: bytes("")
      })
    );
    params[1] = abi.encode(inputCurrency, amountIn);
    params[2] = abi.encode(outputCurrency, minAmountOut);

    // Combine actions and params into inputs
    inputs[0] = abi.encode(actions, params);

    // Execute the swap
    uint256 deadline = block.timestamp + 20;
    if (requireETHValue) {
      require(msg.value == amountIn, "Incorrect ETH amount");
      ROUTER.execute{value: amountIn}(commands, inputs, deadline);
    } else {
      require(msg.value == 0, "ETH not needed for this swap");
      ROUTER.execute(commands, inputs, deadline);
    }

    // Verify and return the output amount
    if (outputTokenAddress == address(0)) amountOut = address(this).balance;
    else amountOut = IERC20(outputTokenAddress).balanceOf(address(this));
    require(amountOut >= minAmountOut, "Insufficient output amount");
    return amountOut;
  }

  function swapExactOutputSingle(
    PoolKey calldata key,
    bool zeroForOne,
    uint128 amountOut,
    uint128 maxAmountIn
  ) external payable returns (uint256 amountIn) {
    // Encode the Universal Router command
    bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
    bytes[] memory inputs = new bytes[](1);

    // Encode V4Router actions - use SWAP_EXACT_OUT_SINGLE for exact output swap
    bytes memory actions = abi.encodePacked(
      uint8(Actions.SWAP_EXACT_OUT_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL)
    );

    // Determine the actual input and output tokens based on zeroForOne
    Currency inputCurrency = zeroForOne ? key.currency0 : key.currency1;
    Currency outputCurrency = zeroForOne ? key.currency1 : key.currency0;
    address inputTokenAddress = Currency.unwrap(inputCurrency);
    address outputTokenAddress = Currency.unwrap(outputCurrency);

    bool requireETHValue = inputTokenAddress == address(0);

    // Prepare parameters for each action
    bytes[] memory params = new bytes[](3);
    params[0] = abi.encode(
      IV4Router.ExactOutputSingleParams({
        poolKey: key,
        zeroForOne: zeroForOne,
        amountOut: amountOut,
        amountInMaximum: maxAmountIn,
        hookData: bytes("")
      })
    );
    params[1] = abi.encode(inputCurrency, maxAmountIn);
    params[2] = abi.encode(outputCurrency, amountOut);

    // Combine actions and params into inputs
    inputs[0] = abi.encode(actions, params);

    // Record balance before execution for ETH input calculation
    uint256 balanceBefore = 0;
    if (requireETHValue) {
      balanceBefore = address(this).balance - msg.value; // Exclude the msg.value we're about to
        // send
    } else if (inputTokenAddress != address(0)) {
      balanceBefore = IERC20(inputTokenAddress).balanceOf(address(this));
    }

    // Execute the swap
    uint256 deadline = block.timestamp + 20;
    if (requireETHValue) {
      require(msg.value >= maxAmountIn, "Insufficient ETH amount");
      ROUTER.execute{value: maxAmountIn}(commands, inputs, deadline);

      // Refund excess ETH if any
      uint256 refund = msg.value - maxAmountIn;
      if (refund > 0) {
        (bool success,) = msg.sender.call{value: refund}("");
        require(success, "ETH refund failed");
      }
    } else {
      require(msg.value == 0, "ETH not needed for this swap");
      ROUTER.execute(commands, inputs, deadline);
    }

    // Calculate the actual amount spent
    if (requireETHValue) {
      // For ETH, calculate how much was spent by checking the balance change
      uint256 currentBalance = address(this).balance;
      amountIn = balanceBefore + msg.value - currentBalance;
    } else {
      // For ERC20 tokens, check how much the token balance decreased
      uint256 currentBalance = IERC20(inputTokenAddress).balanceOf(address(this));
      amountIn = balanceBefore - currentBalance;
    }

    // Verify we didn't spend more than the maximum
    require(amountIn <= maxAmountIn, "Spent more than maximum");

    // For exact output swaps, we verify the output token is as expected
    if (outputTokenAddress == address(0)) {
      // If output is ETH, it should be in the contract's balance
      require(address(this).balance >= amountOut, "Insufficient ETH output");
    } else {
      // If output is ERC20, verify the balance
      require(
        IERC20(outputTokenAddress).balanceOf(address(this)) >= amountOut,
        "Insufficient token output"
      );
    }

    return amountIn;
  }

  function _swapExactInput(
    Currency currencyIn,
    PathKey[] memory path,
    uint128 amountIn,
    uint128 minAmountOut
  ) internal returns (uint256 amountOut) {
    require(path.length > 0, "Path cannot be empty");

    // Encode the Universal Router command for a V4 swap
    bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
    bytes[] memory inputs = new bytes[](1);

    // Encode the sequence of V4Router actions required for a multi-hop exact input swap
    bytes memory actions = abi.encodePacked(
      uint8(Actions.SWAP_EXACT_IN), // Perform the multi-hop swap defined by the path
      uint8(Actions.SETTLE_ALL), // Settle the debt of the input token created by the swap action
      uint8(Actions.TAKE_ALL) // Take the credit of the final output token created by the swap
        // action
    );

    // Determine the final output currency from the last element in the path
    Currency outputCurrency = path[path.length - 1].intermediateCurrency;
    address inputTokenAddress = Currency.unwrap(currencyIn);
    address outputTokenAddress = Currency.unwrap(outputCurrency);

    // Check if the input token is native ETH to handle msg.value
    bool requireETHValue = inputTokenAddress == address(0);

    // Prepare the parameters for each action in the sequence
    bytes[] memory params = new bytes[](3);

    // Params[0]: Parameters for the SWAP_EXACT_IN action
    params[0] = abi.encode(
      IV4Router.ExactInputParams({
        currencyIn: currencyIn,
        path: path,
        amountIn: amountIn,
        amountOutMinimum: minAmountOut // Although checked later, included for struct completeness
      })
    );

    // Params[1]: Parameters for the SETTLE_ALL action (settle the input currency)
    params[1] = abi.encode(currencyIn, amountIn);

    // Params[2]: Parameters for the TAKE_ALL action (take the final output currency)
    params[2] = abi.encode(outputCurrency, minAmountOut);

    // Combine actions and their corresponding parameters into the input for the V4_SWAP command
    inputs[0] = abi.encode(actions, params);

    // Set a deadline for the transaction
    uint256 deadline = block.timestamp + 20; // Using a short deadline (20 seconds)

    // Record balance before execution for ETH output calculation
    uint256 balanceBefore = address(this).balance;

    // Execute the swap via the Universal Router
    if (requireETHValue) {
      require(msg.value == amountIn, "Incorrect ETH amount provided");
      // Pass ETH value if swapping native ETH
      ROUTER.execute{value: amountIn}(commands, inputs, deadline);
    } else {
      require(msg.value == 0, "ETH not required for this swap");
      // Execute without ETH value if swapping ERC20 tokens
      // Assumes necessary approvals (e.g., via Permit2) are already in place
      ROUTER.execute(commands, inputs, deadline);
    }

    // Verify the amount of output tokens received
    if (outputTokenAddress == address(0)) {
      // If the output is native ETH, calculate the *change* in balance
      amountOut = address(this).balance - balanceBefore;
    } else {
      // If the output is an ERC20 token, check the contract's token balance
      amountOut = IERC20(outputTokenAddress).balanceOf(address(this));
    }

    // Ensure the received amount meets the minimum requirement
    require(amountOut >= minAmountOut, "Insufficient output amount");

    // Return the actual amount of output tokens received
    return amountOut;
  }

  receive() external payable virtual {}
}
