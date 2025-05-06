// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.0;

/// @title FeeRetargetLib
/// @notice Pure/view functions for dynamic fee-share retargeting used by SuperDCA pools.
library FeeRetargetLib {
  uint256 internal constant MIN_FEE_SHARE = 1; // 1 wei (18 decimals)
  uint256 internal constant MAX_FEE_SHARE = 1e16; // 1% with 18 decimals precision
  uint256 internal constant GROWTH_FACTOR = 2; // Binary back-off / growth
  uint256 internal constant MAX_HOURS_PAST_INTERVAL = 10; // Cap growth window

  /// @dev Compute the new execution fee share based on time passed.
  /// @param currentFeeShare Current share (18-dec fixed-point, where 1e18 = 100%).
  /// @param lastDistributedAt Timestamp of previous distribution.
  /// @param distributionInterval Target interval.
  /// @return adjustedFeeShare New fee share to apply.
  function adjustFeeShare(
    uint256 currentFeeShare,
    uint256 lastDistributedAt,
    uint256 distributionInterval
  ) internal view returns (uint256 adjustedFeeShare) {
    uint256 timeSinceLast = block.timestamp - lastDistributedAt;

    if (timeSinceLast > distributionInterval) {
      uint256 hoursPast = (timeSinceLast - distributionInterval) / 1 hours;
      if (hoursPast > MAX_HOURS_PAST_INTERVAL) hoursPast = MAX_HOURS_PAST_INTERVAL;
      if (hoursPast == 0) return currentFeeShare;

      adjustedFeeShare = currentFeeShare * (GROWTH_FACTOR ** hoursPast);
      if (adjustedFeeShare > MAX_FEE_SHARE) adjustedFeeShare = MAX_FEE_SHARE;
    } else {
      adjustedFeeShare = currentFeeShare / GROWTH_FACTOR;
      if (adjustedFeeShare < MIN_FEE_SHARE) adjustedFeeShare = MIN_FEE_SHARE;
    }
  }
}
