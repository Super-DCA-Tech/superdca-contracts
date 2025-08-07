// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../contracts/SuperDCAPoolV1.sol";
import "../contracts/SuperDCATrade.sol";

/// @title VerifyImplementation
/// @notice Simple verification script to demonstrate the new functionality works
/// @dev This script shows how multiple pools can share a single SuperDCATrade instance
contract VerifyImplementation is Script {
  // Mock addresses for verification
  address constant MOCK_OPS = 0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0;
  address constant MOCK_ROUTER = 0x851116D9223fabED8E56C0E6b8Ad0c31d98B3507;
  address constant MOCK_POOL_MANAGER = 0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3;
  address constant MOCK_PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

  function run() public {
    console.log("=== Verifying SuperDCATrade Address Configuration ===");

    // Test 1: Deploy with address(0) - should create new SuperDCATrade
    console.log("\n1. Testing backward compatibility (address(0))...");
    SuperDCAPoolV1 pool1 = new SuperDCAPoolV1(
      payable(MOCK_OPS),
      MOCK_ROUTER,
      MOCK_POOL_MANAGER,
      MOCK_PERMIT2,
      address(0)
    );
    console.log("Pool1 deployed at:", address(pool1));
    console.log("Pool1 dcaTrade at:", address(pool1.dcaTrade()));
    require(address(pool1.dcaTrade()) != address(0), "Pool1 should have created dcaTrade");

    // Test 2: Deploy standalone SuperDCATrade
    console.log("\n2. Deploying standalone SuperDCATrade...");
    SuperDCATrade sharedDCATrade = new SuperDCATrade();
    console.log("Shared SuperDCATrade deployed at:", address(sharedDCATrade));

    // Test 3: Deploy pool with existing SuperDCATrade
    console.log("\n3. Testing with existing SuperDCATrade address...");
    SuperDCAPoolV1 pool2 = new SuperDCAPoolV1(
      payable(MOCK_OPS),
      MOCK_ROUTER,
      MOCK_POOL_MANAGER,
      MOCK_PERMIT2,
      address(sharedDCATrade)
    );
    console.log("Pool2 deployed at:", address(pool2));
    console.log("Pool2 dcaTrade at:", address(pool2.dcaTrade()));
    require(address(pool2.dcaTrade()) == address(sharedDCATrade), "Pool2 should use provided dcaTrade");
    require(sharedDCATrade.hasRole(sharedDCATrade.POOL_ROLE(), address(pool2)), "Pool2 should have POOL_ROLE");

    // Test 4: Deploy another pool with same SuperDCATrade
    console.log("\n4. Testing multiple pools with same SuperDCATrade...");
    SuperDCAPoolV1 pool3 = new SuperDCAPoolV1(
      payable(MOCK_OPS),
      MOCK_ROUTER,
      MOCK_POOL_MANAGER,
      MOCK_PERMIT2,
      address(sharedDCATrade)
    );
    console.log("Pool3 deployed at:", address(pool3));
    console.log("Pool3 dcaTrade at:", address(pool3.dcaTrade()));
    require(address(pool3.dcaTrade()) == address(sharedDCATrade), "Pool3 should use provided dcaTrade");
    require(sharedDCATrade.hasRole(sharedDCATrade.POOL_ROLE(), address(pool3)), "Pool3 should have POOL_ROLE");
    require(
      address(pool2.dcaTrade()) == address(pool3.dcaTrade()), 
      "Pool2 and Pool3 should share same dcaTrade"
    );

    // Verification summary
    console.log("\n=== Verification Summary ===");
    console.log("✅ Pool1 (backward compatibility): Created new SuperDCATrade");
    console.log("✅ Pool2 (with existing address): Uses provided SuperDCATrade");
    console.log("✅ Pool3 (with existing address): Uses same SuperDCATrade as Pool2");
    console.log("✅ Multiple pools successfully share single SuperDCATrade instance");
    console.log("✅ All pools have proper POOL_ROLE permissions");
    console.log("\nShared SuperDCATrade address:", address(sharedDCATrade));
    console.log("Pool2 and Pool3 both reference:", address(pool2.dcaTrade()));
    console.log("Addresses match:", address(pool2.dcaTrade()) == address(sharedDCATrade));
    console.log("Pool2 has POOL_ROLE:", sharedDCATrade.hasRole(sharedDCATrade.POOL_ROLE(), address(pool2)));
    console.log("Pool3 has POOL_ROLE:", sharedDCATrade.hasRole(sharedDCATrade.POOL_ROLE(), address(pool3)));

    console.log("\n🎉 Implementation verification complete!");
  }
}