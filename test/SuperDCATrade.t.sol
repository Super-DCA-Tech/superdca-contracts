// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/SuperDCATrade.sol";

contract SuperDCATradeTest is Test {
  SuperDCATrade public superDCA;
  address public owner;
  address public user1;
  address public user2;

  function setUp() public {
    owner = address(this);
    user1 = address(0x1);
    user2 = address(0x2);
    superDCA = new SuperDCATrade();
  }

  // Constructor Tests
  function test_InitialState() public {
    assertEq(superDCA.name(), "SuperDCA Trade");
    assertEq(superDCA.symbol(), "SDCA");
    assertEq(superDCA.owner(), owner);
  }

  // StartTrade Tests
  function test_StartTrade() public {
    int96 flowRate = 1000;
    uint256 indexValue = 100;
    uint256 units = 5;

    superDCA.startTrade(user1, flowRate, indexValue, units);

    SuperDCATrade.Trade memory trade = superDCA.getLatestTrade(user1);
    assertEq(trade.tradeId, 1);
    assertEq(trade.flowRate, flowRate);
    assertEq(trade.startIdaIndex, indexValue);
    assertEq(trade.units, units);
    assertEq(trade.endTime, 0);
    assertEq(superDCA.ownerOf(1), user1);
  }

  function test_RevertWhen_NonOwnerStartsTrade() public {
    vm.prank(user1);
    vm.expectRevert("Ownable: caller is not the owner");
    superDCA.startTrade(user1, 1000, 100, 5);
  }

  // EndTrade Tests
  function test_EndTrade() public {
    // First start a trade
    superDCA.startTrade(user1, 1000, 100, 5);

    uint256 endIndex = 200;
    uint256 refunded = 50;

    superDCA.endTrade(user1, endIndex, refunded);

    SuperDCATrade.Trade memory trade = superDCA.getLatestTrade(user1);
    assertEq(trade.endIdaIndex, endIndex);
    assertEq(trade.refunded, refunded);
    assertGt(trade.endTime, 0);
  }

  function test_RevertWhen_NonOwnerEndsTrade() public {
    superDCA.startTrade(user1, 1000, 100, 5);

    vm.prank(user1);
    vm.expectRevert("Ownable: caller is not the owner");
    superDCA.endTrade(user1, 200, 50);
  }

  function test_RevertWhen_EndingNonExistentTrade() public {
    vm.expectRevert();
    superDCA.endTrade(user1, 200, 50);
  }

  // GetTradeInfo Tests
  function test_GetTradeInfo() public {
    superDCA.startTrade(user1, 1000, 100, 5);
    SuperDCATrade.Trade memory trade = superDCA.getTradeInfo(user1, 0);
    assertEq(trade.tradeId, 1);
    assertEq(trade.flowRate, 1000);
  }

  function test_RevertWhen_GetTradeInfoInvalidIndex() public {
    vm.expectRevert();
    superDCA.getTradeInfo(user1, 0);
  }

  // GetLatestTrade Tests
  function test_GetLatestTrade() public {
    // Create multiple trades
    superDCA.startTrade(user1, 1000, 100, 5);
    superDCA.startTrade(user1, 2000, 200, 10);

    SuperDCATrade.Trade memory trade = superDCA.getLatestTrade(user1);
    assertEq(trade.tradeId, 2);
    assertEq(trade.flowRate, 2000);
  }

  function test_RevertWhen_GetLatestTradeNoTrades() public {
    vm.expectRevert();
    superDCA.getLatestTrade(user1);
  }

  // Multiple Trades Tests
  function test_MultipleTradesForUser() public {
    superDCA.startTrade(user1, 1000, 100, 5);
    superDCA.startTrade(user1, 2000, 200, 10);

    assertEq(superDCA.tradeCountsByUser(user1), 2);

    uint256[] memory userTrades = new uint256[](2);
    userTrades[0] = superDCA.tradesByUser(user1, 0);
    userTrades[1] = superDCA.tradesByUser(user1, 1);

    assertEq(userTrades[0], 1);
    assertEq(userTrades[1], 2);
  }

  // Fuzz Tests
  function testFuzz_StartTrade(int96 flowRate, uint256 indexValue, uint256 units) public {
    vm.assume(flowRate > 0);
    vm.assume(units > 0);

    superDCA.startTrade(user1, flowRate, indexValue, units);

    SuperDCATrade.Trade memory trade = superDCA.getLatestTrade(user1);
    assertEq(trade.flowRate, flowRate);
    assertEq(trade.startIdaIndex, indexValue);
    assertEq(trade.units, units);
  }

  function testFuzz_EndTrade(uint256 endIndex, uint256 refunded) public {
    superDCA.startTrade(user1, 1000, 100, 5);

    superDCA.endTrade(user1, endIndex, refunded);

    SuperDCATrade.Trade memory trade = superDCA.getLatestTrade(user1);
    assertEq(trade.endIdaIndex, endIndex);
    assertEq(trade.refunded, refunded);
  }
}
