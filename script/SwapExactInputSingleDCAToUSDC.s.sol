// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {IUniversalRouter} from "../contracts/external/IUniversalRouter.sol";
import {Commands} from "../contracts/external/Commands.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {console} from "forge-std/console.sol";

contract SwapExactInputSingleDCAToUSDC is Script {
    IUniversalRouter public immutable ROUTER;
    IPermit2 public immutable PERMIT2;
    address public immutable USDC_TOKEN;
    address public immutable DCA_TOKEN;
    address public immutable GAUGE_HOOK;
    // TODO: Replace with the correct IUniversalRouter address for Optimism
    // address public constant OPTIMISM_ROUTER_ADDRESS = 0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD; // Example, verify official V4 address

    constructor() {
        // IMPORTANT: This ROUTER address is for Base. Replace with Optimism router if targeting Optimism.
        ROUTER = IUniversalRouter(0x851116D9223fabED8E56C0E6b8Ad0c31d98B3507); 
        // ROUTER = IUniversalRouter(OPTIMISM_ROUTER_ADDRESS); // Uncomment and use after verifying address
        PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
        USDC_TOKEN = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85; // USDC on Optimism mainnet
        DCA_TOKEN = 0xb1599CDE32181f48f89683d3C5Db5C5D2C7C93cc; // Ensure this is Optimism DCA
        GAUGE_HOOK = 0xb4f4Ad63BCc0102B10e6227236e569Dce0d97A80; // Ensure this is Optimism Hook
    }

    function _approveTokenWithPermit2(address token, uint160 amount, uint48 expiration) internal {
        IERC20(token).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(token, address(ROUTER), amount, expiration);
    }

    function run() external {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Get the deployer address
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer: %s", deployer);
        
        // Log initial balances
        uint256 initialUSDC = IERC20(USDC_TOKEN).balanceOf(deployer);
        uint256 initialDCA = IERC20(DCA_TOKEN).balanceOf(deployer);
        console.log("Initial balances:");
        console.log("USDC: %s", initialUSDC);
        console.log("DCA: %s", initialDCA);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Create pool key for DCA/USDC pool
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(USDC_TOKEN),
            currency1: Currency.wrap(DCA_TOKEN),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG, 
            tickSpacing: 10,
            hooks: IHooks(GAUGE_HOOK)
        });

        // Set swap parameters
        // zeroForOne: false to swap currency1 (DCA) for currency0 (USDC); true to swap currency0 (USDC) for currency1 (DCA)
        bool zeroForOne = false; 
        uint128 amountIn = 10e18; // 10 DCA tokens (assuming 18 decimals for DCA)
        uint128 minAmountOut = 0; // Set your minimum output amount

        // Approve DCA token spending using Permit2
        _approveTokenWithPermit2(DCA_TOKEN, uint160(amountIn), uint48(block.timestamp + 1000));

        // Encode the Universal Router command
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        // Encode V4Router actions
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN_SINGLE),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: zeroForOne,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                hookData: bytes("")
            })
        );
        params[1] = abi.encode(Currency.wrap(DCA_TOKEN), amountIn);
        params[2] = abi.encode(Currency.wrap(USDC_TOKEN), minAmountOut);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        // Execute the swap
        uint256 deadline = block.timestamp + 1000;
        ROUTER.execute{value: 0}(commands, inputs, deadline);

        vm.stopBroadcast();

        // Log final balances
        uint256 finalUSDC = IERC20(USDC_TOKEN).balanceOf(deployer);
        uint256 finalDCA = IERC20(DCA_TOKEN).balanceOf(deployer);
        console.log("\nFinal balances:");
        console.log("USDC: %s", finalUSDC);
        console.log("DCA: %s", finalDCA);

        // Calculate and log the exchange rates
        uint256 dcaSpent = initialDCA - finalDCA;
        uint256 usdcReceived = finalUSDC - initialUSDC;
        console.log("\nSwap details:");
        console.log("DCA spent: %s", dcaSpent);
        console.log("USDC received: %s", usdcReceived);

        // Exchange rate: How many USDC (6 decimals) for 1 DCA (18 decimals), result scaled by 1e18 for logging
        if (dcaSpent > 0) {
            uint256 rate = (usdcReceived * 1e18 * 1e18) / (dcaSpent * 1e6); // (USDC_val * 10^18 * 10^18) / (DCA_val * 10^6)
            console.log("Exchange rate: 1 DCA = %s USDC (scaled by 1e18)", rate);
        } else {
            console.log("Exchange rate: Cannot calculate, DCA spent is zero.");
        }
    }
} 