// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "./DeploySuperDCATrade.s.sol";
import "./OptimismDeployWithExistingTrade.s.sol";

/// @title FullOptimismDeploy
/// @notice Complete deployment script that demonstrates the modular approach
/// @dev This script first deploys SuperDCATrade, then deploys multiple SuperDCAPool instances that reference it
contract FullOptimismDeploy is Script {
  uint256 public deployerPrivateKey;

  function setUp() public virtual {
    deployerPrivateKey = vm.envUint("PRIVATE_KEY");
  }

  function run() public returns (SuperDCATrade, SuperDCAPoolV1[] memory) {
    vm.startBroadcast(deployerPrivateKey);

    console.log("=== Starting Full Optimism Deployment ===");

    // Step 1: Deploy SuperDCATrade contract
    console.log("1. Deploying SuperDCATrade...");
    DeploySuperDCATrade tradeDeployer = new DeploySuperDCATrade();
    SuperDCATrade dcaTrade = tradeDeployer.run();
    console.log("SuperDCATrade deployed at:", address(dcaTrade));

    // Step 2: Deploy multiple SuperDCAPool instances that reference the same SuperDCATrade
    console.log("2. Deploying SuperDCAPool instances...");
    SuperDCAPoolV1[] memory pools = new SuperDCAPoolV1[](2);
    
    // Deploy first pool
    console.log("2a. Deploying first SuperDCAPool...");
    OptimismDeployWithExistingTrade poolDeployer1 = new OptimismDeployWithExistingTrade(address(dcaTrade));
    (SuperDCAPoolV1 pool1, SuperDCATrade returnedTrade1) = poolDeployer1.run();
    pools[0] = pool1;
    console.log("First SuperDCAPool deployed at:", address(pool1));
    console.log("Pool1 dcaTrade address:", address(pool1.dcaTrade()));
    
    // Deploy second pool
    console.log("2b. Deploying second SuperDCAPool...");
    OptimismDeployWithExistingTrade poolDeployer2 = new OptimismDeployWithExistingTrade(address(dcaTrade));
    (SuperDCAPoolV1 pool2, SuperDCATrade returnedTrade2) = poolDeployer2.run();
    pools[1] = pool2;
    console.log("Second SuperDCAPool deployed at:", address(pool2));
    console.log("Pool2 dcaTrade address:", address(pool2.dcaTrade()));

    // Verify both pools reference the same SuperDCATrade contract
    require(address(pool1.dcaTrade()) == address(dcaTrade), "Pool1 dcaTrade mismatch");
    require(address(pool2.dcaTrade()) == address(dcaTrade), "Pool2 dcaTrade mismatch");
    require(address(pool1.dcaTrade()) == address(pool2.dcaTrade()), "Pools dcaTrade mismatch");

    console.log("=== Deployment Complete ===");
    console.log("SuperDCATrade address:", address(dcaTrade));
    console.log("Pool1 address:", address(pool1));
    console.log("Pool2 address:", address(pool2));
    console.log("All pools reference the same SuperDCATrade contract!");

    vm.stopBroadcast();

    return (dcaTrade, pools);
  }
}