// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract SuperDCATrade is AccessControl, ERC721 {
  bytes32 public constant POOL_ROLE = keccak256("POOL_ROLE");
  struct Trade {
    uint256 tradeId;
    uint256 startTime;
    uint256 endTime;
    int96 flowRate;
    uint256 startIdaIndex;
    uint256 endIdaIndex;
    uint256 units;
    uint256 refunded;
  }

  uint256 private _nextTradeId;
  mapping(uint256 => Trade) public trades;
  mapping(address => uint256[]) public tradesByUser;
  mapping(address => uint256) public tradeCountsByUser;

  event TradeStarted(address indexed trader, uint256 indexed tradeId);
  event TradeEnded(address indexed trader, uint256 indexed tradeId);

  constructor() ERC721("SuperDCA Trade", "SDCA") {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  /// @notice Grant pool role to an address
  /// @param pool Address of the pool contract to authorize
  function grantPoolRole(address pool) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _grantRole(POOL_ROLE, pool);
  }

  /// @notice Revoke pool role from an address  
  /// @param pool Address of the pool contract to revoke authorization from
  function revokePoolRole(address pool) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _revokeRole(POOL_ROLE, pool);
  }

  function startTrade(address _shareholder, int96 _flowRate, uint256 _indexValue, uint256 _units)
    external
    onlyRole(POOL_ROLE)
  {
    // Mint the shareholder an NFT to track this trade
    uint256 tradeId = _nextTradeId + 1;
    _nextTradeId += 1;

    trades[tradeId] = Trade({
      tradeId: tradeId,
      startTime: block.timestamp,
      endTime: 0,
      flowRate: _flowRate,
      startIdaIndex: _indexValue,
      endIdaIndex: 0,
      units: _units,
      refunded: 0
    });
    tradesByUser[_shareholder].push(tradeId);
    tradeCountsByUser[_shareholder] += 1;
    _safeMint(_shareholder, tradeId);

    emit TradeStarted(_shareholder, tradeId);
  }

  function endTrade(address _shareholder, uint256 _indexValue, uint256 _refunded)
    external
    onlyRole(POOL_ROLE)
  {
    // Get the trade for this shareholder, will always be the last one in the list
    Trade storage trade = trades[tradesByUser[_shareholder][tradesByUser[_shareholder].length - 1]];

    // Update the trade
    trade.endTime = block.timestamp;
    trade.endIdaIndex = _indexValue;
    trade.refunded = _refunded;

    emit TradeEnded(_shareholder, trade.tradeId);
  }

  function getLatestTrade(address _trader) external view returns (Trade memory trade) {
    require(tradesByUser[_trader].length > 0, "No trades");
    trade = trades[tradesByUser[_trader][tradesByUser[_trader].length - 1]];
  }

  function getTradeInfo(address _trader, uint256 _index) external view returns (Trade memory trade) {
    require(_index < tradesByUser[_trader].length, "Invalid trade index");
    trade = trades[tradesByUser[_trader][_index]];
  }
}
