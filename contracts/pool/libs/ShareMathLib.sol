// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.0;

/// @title ShareMathLib
/// @notice Helper, stateless math utilities for share/unit calculations used by SuperDCA pools.
library ShareMathLib {
  uint128 internal constant SHARE_SCALER = 100_000; // Same value as in pool

  /// @dev Calculate uninvested amount for a stream.
  /// @param prevUpdateTimestamp Last update or stream start time.
  /// @param flowRate The stream flow rate (tokens/sec, 9-dec scaled).
  /// @param lastDistributedAt Global last distribution timestamp.
  function calcUserUninvested(
    uint256 prevUpdateTimestamp,
    uint256 flowRate,
    uint256 lastDistributedAt
  ) internal view returns (uint256 uninvestedAmount) {
    uint256 since = block.timestamp
      - (prevUpdateTimestamp > lastDistributedAt ? prevUpdateTimestamp : lastDistributedAt);
    uninvestedAmount = flowRate * since;
  }

  /// @dev Convert a flowRate into IDA unit shares (scaled down by SHARE_SCALER).
  function flowRateToShares(int96 currentFlowRate) internal pure returns (uint128 shares) {
    shares = uint128(uint256(int256(currentFlowRate)));
    shares /= SHARE_SCALER;
  }
}
