// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {SuperDCAPoolV1} from "../contracts/SuperDCAPoolV1.sol";
import {console} from "forge-std/console.sol";
/// @title DistributeNoGas
/// @notice This script calls the distribute function on a SuperDCAPoolV1 contract
///         with the ignoreGasReimbursement flag set to true.
contract DistributeNoGas is Script {
    // !!! IMPORTANT !!!
    // Replace this with the actual address of your deployed SuperDCAPoolV1 contract
    address public constant POOL_ADDRESS = 0x14e86edd215203B534334F1F66e2e7df8a3c4372;

    SuperDCAPoolV1 public pool;
    uint256 public deployerPrivateKey;


    function setUp() public {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        console.log("Deployer address:", vm.addr(deployerPrivateKey));

        if (POOL_ADDRESS == address(0)) {
            revert("DistributeNoGas: POOL_ADDRESS not set. Please update the script with the deployed SuperDCAPoolV1 address.");
        }
        pool = SuperDCAPoolV1(payable(POOL_ADDRESS));
    }

    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        bytes memory ctx = ""; // Empty context
        bool ignoreGasReimbursement = true;

        console.log("Calling distribute on pool: %s", POOL_ADDRESS);
        pool.distribute(ctx, ignoreGasReimbursement);
        console.log("distribute called successfully.");

        vm.stopBroadcast();
    }
} 