// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title SuperDCA Pool – Staking & Executor selection mix-in
/// @dev Isolates staking logic so it can be reused or audited independently.
abstract contract SuperDCAPoolStaking {
  using SafeERC20 for ERC20;

  // -------------------------------------------------------------------------
  // Storage
  // -------------------------------------------------------------------------

  /// @notice ERC-20 token used for staking (DCA governance token)
  address public constant STAKING_TOKEN_ADDRESS = 0xb1599CDE32181f48f89683d3C5Db5C5D2C7C93cc;

  /// @notice Address that currently holds the executor role (Gelato task caller)
  address public currentExecutor;

  /// @notice Amount of `STAKING_TOKEN_ADDRESS` staked by the `currentExecutor`
  uint256 public currentStake;

  // -------------------------------------------------------------------------
  // Events
  // -------------------------------------------------------------------------

  event NewExecutor(
    address indexed previousExecutor, address indexed newExecutor, uint256 newStake
  );

  event StakeReturned(address indexed executor, uint256 amount);

  // -------------------------------------------------------------------------
  // Custom errors
  // -------------------------------------------------------------------------

  error StakeTooLow();
  error NotCurrentExecutor();

  // -------------------------------------------------------------------------
  // External functions
  // -------------------------------------------------------------------------

  /// @notice Stake tokens to become the executor.
  /// @dev Caller must stake strictly more than the current stake. Transfers are
  ///      performed with SafeERC20 to bubble up potential failures.
  /// @param amount Amount of tokens to stake
  function stake(uint256 amount) external {
    if (amount <= currentStake) revert StakeTooLow();

    // Snapshot previous state
    address previousExecutor = currentExecutor;
    uint256 previousStake = currentStake;

    // Update executor state first (checks-effects-interactions)
    currentExecutor = msg.sender;
    currentStake = amount;

    // Pull the new stake
    ERC20(STAKING_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), amount);

    // Return previous stake if there was one
    if (previousExecutor != address(0)) {
      ERC20(STAKING_TOKEN_ADDRESS).safeTransfer(previousExecutor, previousStake);
      emit StakeReturned(previousExecutor, previousStake);
    }

    emit NewExecutor(previousExecutor, currentExecutor, amount);
  }

  /// @notice Withdraw stake when renouncing executor role.
  /// @dev Only callable by the `currentExecutor`.
  function unstake() external {
    if (msg.sender != currentExecutor) revert NotCurrentExecutor();

    uint256 stakeAmount = currentStake;

    // Reset state
    currentStake = 0;
    currentExecutor = address(0);
    emit NewExecutor(currentExecutor, address(0), 0);

    // Return stake
    ERC20(STAKING_TOKEN_ADDRESS).safeTransfer(msg.sender, stakeAmount);
    emit StakeReturned(msg.sender, stakeAmount);
  }
}
