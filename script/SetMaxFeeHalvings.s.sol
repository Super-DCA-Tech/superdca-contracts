// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {SuperDCAPoolV1} from "../contracts/SuperDCAPoolV1.sol";
import {console} from "forge-std/console.sol";

/// @title SetMaxFeeHalvings
/// @notice This script calls the setMaxFeeHalvings function on a SuperDCAPoolV1 contract
contract SetMaxFeeHalvings is Script {
    // !!! IMPORTANT !!!
    // Replace this with the actual address of your deployed SuperDCAPoolV1 contract
    address public constant POOL_ADDRESS = 0x07d9d75Ebe3f7C14a166c80717F394547ce9461D;

    SuperDCAPoolV1 public pool;
    uint256 public deployerPrivateKey;

    function setUp() public {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        console.log("Deployer address:", vm.addr(deployerPrivateKey));

        if (POOL_ADDRESS == address(0)) {
            revert("SetMaxFeeHalvings: POOL_ADDRESS not set. Please update the script with the deployed SuperDCAPoolV1 address.");
        }
        pool = SuperDCAPoolV1(payable(POOL_ADDRESS));
    }

    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        // Get current value
        uint256 currentMaxFeeHalvings = pool.maxFeeHalvings();
        console.log("Current maxFeeHalvings:", currentMaxFeeHalvings);

        // Set new value (example: setting to 10)
        uint256 newMaxFeeHalvings = 10;
        console.log("Setting maxFeeHalvings to:", newMaxFeeHalvings);
        
        pool.setMaxFeeHalvings(newMaxFeeHalvings);
        console.log("setMaxFeeHalvings called successfully");

        // Reset baseFeeShare to its original value by calling setGelatoFeeShare
        // The original gelatoFeeShare (and thus baseFeeShare) in SuperDCAPoolV1 is 1e16
        uint256 originalBaseFeeShare = 1e16; // 1%

        // Log current baseFeeShare before updating
        uint256 currentBaseFeeShare = pool.baseFeeShare();
        console.log("Current baseFeeShare before reset:", currentBaseFeeShare);

        console.log("Resetting baseFeeShare to its original value:", originalBaseFeeShare);
        pool.setGelatoFeeShare(originalBaseFeeShare);
        console.log("setGelatoFeeShare called successfully to reset baseFeeShare");

        // Verify the new value
        uint256 updatedMaxFeeHalvings = pool.maxFeeHalvings();
        console.log("New maxFeeHalvings value:", updatedMaxFeeHalvings);

        vm.stopBroadcast();
    }
} 