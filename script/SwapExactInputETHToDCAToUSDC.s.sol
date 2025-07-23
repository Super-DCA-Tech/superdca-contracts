// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import "./SwapExecutor.sol";

/// @notice Foundry script that performs the full swap flow via a single
///         call into `SwapExecutor`.
contract SwapExactInputETHToDCAToUSDC is Script {
    uint128 public constant AMOUNT_IN_ETH = 0.01 ether;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        uint256 initialETHBalance = deployer.balance;

        vm.startBroadcast(deployerPrivateKey);

        // Deploy a fresh executor and perform the swap atomically.
        SwapExecutor executor = new SwapExecutor();
        executor.execute{value: AMOUNT_IN_ETH}(AMOUNT_IN_ETH);

        vm.stopBroadcast();

        uint256 finalETHBalance = deployer.balance;

        // if (finalETHBalance < initialETHBalance) {
        //     revert("Swap resulted in a loss of ETH.");
        // }
    }
} 