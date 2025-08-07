// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {SuperDCAPoolV1} from "../contracts/SuperDCAPoolV1.sol";
import {SuperDCATrade} from "../contracts/SuperDCATrade.sol";

/// @title SuperDCAPoolConstructorTest
/// @notice Test suite for the new SuperDCAPool constructor functionality
/// @dev Tests the new constructor parameter that allows setting SuperDCATrade address
contract SuperDCAPoolConstructorTest is Test {
  // Mock addresses for testing
  address constant MOCK_OPS = 0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0;
  address constant MOCK_ROUTER = 0x851116D9223fabED8E56C0E6b8Ad0c31d98B3507;
  address constant MOCK_POOL_MANAGER = 0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3;
  address constant MOCK_PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

  function test_constructor_withExistingDCATrade() public {
    // Deploy a SuperDCATrade contract first
    SuperDCATrade existingDCATrade = new SuperDCATrade();
    
    // Deploy SuperDCAPool with the existing SuperDCATrade address
    SuperDCAPoolV1 pool = new SuperDCAPoolV1(
      payable(MOCK_OPS),
      MOCK_ROUTER,
      MOCK_POOL_MANAGER,
      MOCK_PERMIT2,
      address(existingDCATrade)
    );

    // Verify that the pool uses the provided SuperDCATrade contract
    assertEq(address(pool.dcaTrade()), address(existingDCATrade), "Pool should use provided SuperDCATrade address");
    
    // Verify that the pool has the POOL_ROLE
    assertTrue(existingDCATrade.hasRole(existingDCATrade.POOL_ROLE(), address(pool)), "Pool should have POOL_ROLE");
    
    console.log("✅ Pool successfully uses provided SuperDCATrade address");
    console.log("Expected:", address(existingDCATrade));
    console.log("Actual:  ", address(pool.dcaTrade()));
    console.log("✅ Pool has POOL_ROLE");
  }

  function test_constructor_withZeroAddress() public {
    // Deploy SuperDCAPool with zero address (should create new SuperDCATrade)
    SuperDCAPoolV1 pool = new SuperDCAPoolV1(
      payable(MOCK_OPS),
      MOCK_ROUTER,
      MOCK_POOL_MANAGER,
      MOCK_PERMIT2,
      address(0)
    );

    // Verify that the pool created a new SuperDCATrade contract
    assertTrue(address(pool.dcaTrade()) != address(0), "Pool should create new SuperDCATrade when address is zero");
    
    // Verify that the pool has the POOL_ROLE on the newly created SuperDCATrade
    assertTrue(pool.dcaTrade().hasRole(pool.dcaTrade().POOL_ROLE(), address(pool)), "Pool should have POOL_ROLE on new SuperDCATrade");
    
    console.log("✅ Pool successfully created new SuperDCATrade when address is zero");
    console.log("Created dcaTrade at:", address(pool.dcaTrade()));
    console.log("✅ Pool has POOL_ROLE on new SuperDCATrade");
  }

  function test_constructor_backwardCompatibility() public {
    // This test simulates the old constructor call (without dcaTrade parameter)
    // We'll test this by using address(0) which should maintain backward compatibility
    SuperDCAPoolV1 pool = new SuperDCAPoolV1(
      payable(MOCK_OPS),
      MOCK_ROUTER,
      MOCK_POOL_MANAGER,
      MOCK_PERMIT2,
      address(0) // Simulates not providing the parameter
    );

    // Verify that a new SuperDCATrade contract was created
    assertTrue(address(pool.dcaTrade()) != address(0), "Pool should create new SuperDCATrade for backward compatibility");
    
    // Verify that the pool has the POOL_ROLE
    assertTrue(pool.dcaTrade().hasRole(pool.dcaTrade().POOL_ROLE(), address(pool)), "Pool should have POOL_ROLE for backward compatibility");
    
    console.log("✅ Backward compatibility maintained");
    console.log("Created dcaTrade at:", address(pool.dcaTrade()));
    console.log("✅ Pool has POOL_ROLE for backward compatibility");
  }

  function test_multiplePools_sameDCATrade() public {
    // Deploy a single SuperDCATrade contract
    SuperDCATrade sharedDCATrade = new SuperDCATrade();
    
    // Deploy multiple SuperDCAPool contracts that reference the same SuperDCATrade
    SuperDCAPoolV1 pool1 = new SuperDCAPoolV1(
      payable(MOCK_OPS),
      MOCK_ROUTER,
      MOCK_POOL_MANAGER,
      MOCK_PERMIT2,
      address(sharedDCATrade)
    );

    SuperDCAPoolV1 pool2 = new SuperDCAPoolV1(
      payable(MOCK_OPS),
      MOCK_ROUTER,
      MOCK_POOL_MANAGER,
      MOCK_PERMIT2,
      address(sharedDCATrade)
    );

    // Verify both pools reference the same SuperDCATrade contract
    assertEq(
      address(pool1.dcaTrade()), 
      address(sharedDCATrade), 
      "Pool1 should reference shared SuperDCATrade"
    );
    assertEq(
      address(pool2.dcaTrade()), 
      address(sharedDCATrade), 
      "Pool2 should reference shared SuperDCATrade"
    );
    assertEq(
      address(pool1.dcaTrade()), 
      address(pool2.dcaTrade()), 
      "Both pools should reference the same SuperDCATrade"
    );

    // Verify both pools have the POOL_ROLE
    assertTrue(sharedDCATrade.hasRole(sharedDCATrade.POOL_ROLE(), address(pool1)), "Pool1 should have POOL_ROLE");
    assertTrue(sharedDCATrade.hasRole(sharedDCATrade.POOL_ROLE(), address(pool2)), "Pool2 should have POOL_ROLE");

    console.log("✅ Multiple pools successfully share the same SuperDCATrade contract");
    console.log("Shared dcaTrade:", address(sharedDCATrade));
    console.log("Pool1 dcaTrade:", address(pool1.dcaTrade()));
    console.log("Pool2 dcaTrade:", address(pool2.dcaTrade()));
    console.log("✅ Both pools have POOL_ROLE");
  }

  function test_dcaTrade_accessControl() public {
    // Deploy a SuperDCATrade contract
    SuperDCATrade dcaTrade = new SuperDCATrade();
    
    // Deploy SuperDCAPool with the SuperDCATrade address
    SuperDCAPoolV1 pool = new SuperDCAPoolV1(
      payable(MOCK_OPS),
      MOCK_ROUTER,
      MOCK_POOL_MANAGER,
      MOCK_PERMIT2,
      address(dcaTrade)
    );

    // The deployer (this test contract) should have DEFAULT_ADMIN_ROLE
    assertTrue(dcaTrade.hasRole(dcaTrade.DEFAULT_ADMIN_ROLE(), address(this)), "Deployer should have DEFAULT_ADMIN_ROLE");
    
    // The pool should have POOL_ROLE
    assertTrue(dcaTrade.hasRole(dcaTrade.POOL_ROLE(), address(pool)), "Pool should have POOL_ROLE");
    
    // Test that we can grant/revoke pool roles as admin
    address dummyPool = address(0x1234);
    dcaTrade.grantPoolRole(dummyPool);
    assertTrue(dcaTrade.hasRole(dcaTrade.POOL_ROLE(), dummyPool), "Should be able to grant POOL_ROLE");
    
    dcaTrade.revokePoolRole(dummyPool);
    assertFalse(dcaTrade.hasRole(dcaTrade.POOL_ROLE(), dummyPool), "Should be able to revoke POOL_ROLE");

    console.log("✅ SuperDCATrade access control works correctly");
  }
}