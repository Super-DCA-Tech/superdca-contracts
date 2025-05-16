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
import {PathKey} from "@uniswap/v4-periphery/src/libraries/PathKey.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {console} from "forge-std/console.sol";

contract SwapExactInputUSDCToDCAToETH is Script {
    IUniversalRouter public immutable ROUTER;
    IPermit2 public immutable PERMIT2;
    address public immutable USDC_TOKEN;
    address public immutable DCA_TOKEN;
    address public immutable GAUGE_HOOK;

    constructor() {
        ROUTER = IUniversalRouter(0x851116D9223fabED8E56C0E6b8Ad0c31d98B3507);
        PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
        USDC_TOKEN = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85; // USDC on mainnet
        DCA_TOKEN = 0xb1599CDE32181f48f89683d3C5Db5C5D2C7C93cc;
        GAUGE_HOOK = 0xb4f4Ad63BCc0102B10e6227236e569Dce0d97A80;
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
        
        // Log initial balances
        uint256 initialUSDC = IERC20(USDC_TOKEN).balanceOf(deployer);
        uint256 initialDCA = IERC20(DCA_TOKEN).balanceOf(deployer);
        uint256 initialETH = deployer.balance;
        console.log("Initial balances:");
        console.log("USDC: %s", initialUSDC);
        console.log("DCA: %s", initialDCA);
        console.log("ETH: %s", initialETH);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Create pool keys for both pools
        PoolKey memory usdcDcaPool = PoolKey({
            currency0: Currency.wrap(USDC_TOKEN),
            currency1: Currency.wrap(DCA_TOKEN),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 10,
            hooks: IHooks(GAUGE_HOOK)
        });

        PoolKey memory dcaEthPool = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(DCA_TOKEN),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 10,
            hooks: IHooks(GAUGE_HOOK)
        });

        // Set swap parameters
        uint128 amountIn = 1e6; // 1 USDC (6 decimals)

        // Create the path
        PathKey[] memory path = new PathKey[](2);
        path[0] = PathKey({
            intermediateCurrency: Currency.wrap(DCA_TOKEN),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 10,
            hooks: IHooks(GAUGE_HOOK),
            hookData: bytes("")
        });
        path[1] = PathKey({
            intermediateCurrency: Currency.wrap(address(0)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 10,
            hooks: IHooks(GAUGE_HOOK),
            hookData: bytes("")
        });

        // Approve USDC token spending using Permit2
        _approveTokenWithPermit2(USDC_TOKEN, uint160(1e6), uint48(block.timestamp + 20));

        // Encode the Universal Router command
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        // Encode V4Router actions
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputParams({
                currencyIn: Currency.wrap(USDC_TOKEN),
                path: path,
                amountIn: amountIn,
                amountOutMinimum: 0
            })
        );
        params[1] = abi.encode(Currency.wrap(USDC_TOKEN), amountIn);
        params[2] = abi.encode(Currency.wrap(address(0)), 0);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        // Execute the swap
        ROUTER.execute(commands, inputs, block.timestamp + 20);

        vm.stopBroadcast();

        // Log final balances
        uint256 finalUSDC = IERC20(USDC_TOKEN).balanceOf(deployer);
        uint256 finalDCA = IERC20(DCA_TOKEN).balanceOf(deployer);
        uint256 finalETH = deployer.balance;
        console.log("\nFinal balances:");
        console.log("USDC: %s", finalUSDC);
        console.log("DCA: %s", finalDCA);
        console.log("ETH: %s", finalETH);

        // Calculate and log the exchange rates
        uint256 usdcSpent = initialUSDC - finalUSDC;
        uint256 ethReceived = finalETH - initialETH;
        console.log("\nSwap details:");
        console.log("USDC spent: %s", usdcSpent);
        console.log("ETH received: %s", ethReceived);
        console.log("Exchange rate: 1 USDC = %s ETH", (ethReceived * 1e18) / usdcSpent);
    }
} 