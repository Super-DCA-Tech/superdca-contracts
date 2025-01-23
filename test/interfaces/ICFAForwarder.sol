// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ISuperToken} from
  "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

interface ICFAForwarder {
  function createFlow(
    ISuperToken token,
    address sender,
    address receiver,
    int96 flowRate,
    bytes calldata userData
  ) external;

  function updateFlow(
    ISuperToken token,
    address sender,
    address receiver,
    int96 flowRate,
    bytes calldata userData
  ) external;

  function deleteFlow(ISuperToken token, address sender, address receiver, bytes calldata userData)
    external;

  function getFlow(ISuperToken token, address sender, address receiver)
    external
    view
    returns (uint256 flowRate, uint256 deposit, uint256 owedDeposit, uint256 owedFraction);

  function getFlowInfo(ISuperToken token, address sender, address receiver)
    external
    view
    returns (uint256 flowRate, uint256 deposit, uint256 owedDeposit, uint256 owedFraction);
}
