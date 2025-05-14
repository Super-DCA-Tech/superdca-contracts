// SPDX-License-Identifier: AGPLv3

pragma solidity >=0.6.0;
pragma abicoder v2;

uint32 constant OUTPUT_INDEX = 0; // Superfluid IDA Index for outputToken's output pool
uint256 constant INTERVAL = 60; // The interval for gelato to check for execution
uint256 constant EXEC_FEE_SCALER = 1e18; // The scaler for the execution fee (1e18 = 100%)
// TODO: make's minoutput 0 for simulation
uint256 constant RATE_TOLERANCE = 1e4; // The percentage to deviate from the oracle (basis
// points)
uint128 constant SHARE_SCALER = 100_000; // The scaler to apply to the share of the
// outputToken pool

// Uniswap V4 Constants
address constant USDC_ADDRESS = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
address constant DCA_ADDRESS = 0xb1599CDE32181f48f89683d3C5Db5C5D2C7C93cc;
address constant ETH_ADDRESS = address(0);
// Constants for fee retargeting calculations

uint256 constant DECIMALS = 18;
uint256 constant MIN_FEE_SHARE = 1; // 1 wei lower bound
uint256 constant MAX_FEE_SHARE = 1e16; // 1% = 0.01 = 1e16 (with 18 decimals)
uint256 constant GROWTH_FACTOR = 2; // Simple multiplier of 2
uint256 constant MAX_HOURS_PAST_INTERVAL = 10; // Maximum hours past the interval to
