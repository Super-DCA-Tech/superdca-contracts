// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../contracts/SuperDCATrade.sol";

/// @title DeploySuperDCATrade
/// @notice Script to deploy SuperDCATrade contract separately for reuse across multiple pools
contract DeploySuperDCATrade is Script {
  uint256 public deployerPrivateKey;

  function setUp() public {
    deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    console.log("Deployer address:", vm.addr(deployerPrivateKey));
  }

  function run() public returns (SuperDCATrade) {
    vm.startBroadcast(deployerPrivateKey);

    // Deploy SuperDCATrade contract
    SuperDCATrade dcaTrade = new SuperDCATrade();

    console.log("SuperDCATrade deployed at:", address(dcaTrade));

    vm.stopBroadcast();
    return dcaTrade;
  }
}