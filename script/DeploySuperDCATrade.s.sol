// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../contracts/SuperDCATrade.sol";

/// @title DeploySuperDCATrade
/// @notice Deployment script for SuperDCATrade contract
/// @dev This script deploys a standalone SuperDCATrade contract that can be reused across multiple SuperDCAPool deployments
contract DeploySuperDCATrade is Script {
  uint256 public deployerPrivateKey;

  function setUp() public virtual {
    deployerPrivateKey = vm.envUint("PRIVATE_KEY");
  }

  function run() public returns (SuperDCATrade) {
    vm.startBroadcast(deployerPrivateKey);

    // Deploy SuperDCATrade contract
    SuperDCATrade dcaTrade = new SuperDCATrade();

    vm.stopBroadcast();

    return dcaTrade;
  }
}