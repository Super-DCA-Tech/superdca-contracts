// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/SuperDCAPoolV1.sol";
import "../contracts/SuperDCATrade.sol";

contract SuperDCAPoolV1ConstructorTest is Test {
  address public constant GELATO_AUTOMATE = 0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0;
  address public constant UNIVERSAL_ROUTER = 0x6fF5693b99212Da76ad316178A184AB56D299b43;
  address public constant POOL_MANAGER = 0x498581fF718922c3f8e6A244956aF099B2652b2b;
  address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

  function test_ConstructorWithZeroAddressCreatesNewTrade() public {
    // Deploy pool with zero address for SuperDCATrade
    SuperDCAPoolV1 pool = new SuperDCAPoolV1(
      payable(GELATO_AUTOMATE),
      UNIVERSAL_ROUTER,
      POOL_MANAGER,
      PERMIT2,
      address(0)
    );

    // Should have created a new SuperDCATrade instance
    assertTrue(address(pool.dcaTrade()) != address(0));
    assertEq(pool.dcaTrade().owner(), address(pool));
  }

  function test_ConstructorWithExistingTradeAddress() public {
    // First deploy a SuperDCATrade contract
    SuperDCATrade existingTrade = new SuperDCATrade();
    
    // Deploy pool with existing SuperDCATrade address
    SuperDCAPoolV1 pool = new SuperDCAPoolV1(
      payable(GELATO_AUTOMATE),
      UNIVERSAL_ROUTER,
      POOL_MANAGER,
      PERMIT2,
      address(existingTrade)
    );

    // Should use the existing SuperDCATrade instance
    assertEq(address(pool.dcaTrade()), address(existingTrade));
    assertEq(pool.dcaTrade().owner(), address(this)); // Original owner
  }

  function test_MultiplPoolsCanShareSuperDCATrade() public {
    // First deploy a SuperDCATrade contract
    SuperDCATrade sharedTrade = new SuperDCATrade();
    
    // Deploy two pools with the same SuperDCATrade address
    SuperDCAPoolV1 pool1 = new SuperDCAPoolV1(
      payable(GELATO_AUTOMATE),
      UNIVERSAL_ROUTER,
      POOL_MANAGER,
      PERMIT2,
      address(sharedTrade)
    );

    SuperDCAPoolV1 pool2 = new SuperDCAPoolV1(
      payable(GELATO_AUTOMATE),
      UNIVERSAL_ROUTER,
      POOL_MANAGER,
      PERMIT2,
      address(sharedTrade)
    );

    // Both pools should reference the same SuperDCATrade instance
    assertEq(address(pool1.dcaTrade()), address(sharedTrade));
    assertEq(address(pool2.dcaTrade()), address(sharedTrade));
    assertEq(address(pool1.dcaTrade()), address(pool2.dcaTrade()));
  }
}