// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {SuperDCAPoolV1} from "../contracts/SuperDCAPoolV1.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/// @title DistributeNoGas
/// @notice This script calls the distribute function on a SuperDCAPoolV1 contract
///         with the ignoreGasReimbursement flag set to true.
contract DistributeNoGas is Script {
    // !!! IMPORTANT !!!
    // Replace this with the actual address of your deployed SuperDCAPoolV1 contract
    address public constant POOL_ADDRESS = 0x07d9d75Ebe3f7C14a166c80717F394547ce9461D;

    SuperDCAPoolV1 public pool;
    uint256 public deployerPrivateKey;

    // Token Addresses
    address internal constant USDCx_ADDRESS = 0x35Adeb0638EB192755B6E52544650603Fe65A006;
    address internal constant ETHx_ADDRESS = 0x4ac8bD1bDaE47beeF2D1c6Aa62229509b962Aa0d;


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

        IERC20 usdcx = IERC20(USDCx_ADDRESS);
        IERC20 ethx = IERC20(ETHx_ADDRESS);

        console.log("--- Balances Before Distribute ---");
        uint256 initialUsdcxBalance = usdcx.balanceOf(0xC07E21c78d6Ad0917cfCBDe8931325C392958892);
        uint256 initialEthxBalance = ethx.balanceOf(0xC07E21c78d6Ad0917cfCBDe8931325C392958892);
        console.log("Pool USDCx Balance:", initialUsdcxBalance);
        console.log("Pool ETHx Balance:", initialEthxBalance);
        console.log("---------------------------------");

        bytes memory ctx = ""; // Empty context
        bool ignoreGasReimbursement = true;

        console.log("Calling distribute on pool: %s", POOL_ADDRESS);
        pool.distribute(ctx, ignoreGasReimbursement);
        console.log("distribute called successfully.");

        console.log("--- Balances After Distribute ---");
        uint256 finalUsdcxBalance = usdcx.balanceOf(0xC07E21c78d6Ad0917cfCBDe8931325C392958892);
        uint256 finalEthxBalance = ethx.balanceOf(0xC07E21c78d6Ad0917cfCBDe8931325C392958892);
        console.log("Pool USDCx Balance:", finalUsdcxBalance);
        console.log("Pool ETHx Balance:", finalEthxBalance);
        console.log("--------------------------------");

        // Calculate exchange rate based on token deltas
        int256 usdcxDelta = int256(finalUsdcxBalance) - int256(initialUsdcxBalance);
        int256 ethxDelta = int256(finalEthxBalance) - int256(initialEthxBalance);
        
        if (ethxDelta != 0) {
            console.log("Exchange rate (USDCx/ETHx):", uint256((-usdcxDelta * 1e18) / ethxDelta));
        } else {
            console.log("No exchange occurred (ETHx delta is 0)");
        }

        vm.stopBroadcast();
    }
} 