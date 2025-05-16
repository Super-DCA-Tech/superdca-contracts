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

contract SwapExactInputSingleETHToDCA is Script {
    IUniversalRouter public immutable ROUTER;
    IPermit2 public immutable PERMIT2;

    constructor() {
        ROUTER = IUniversalRouter(0x851116D9223fabED8E56C0E6b8Ad0c31d98B3507);
        PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    }

    function _approveTokenWithPermit2(address token, uint160 amount, uint48 expiration) internal {
        IERC20(token).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(token, address(ROUTER), amount, expiration);
    }

    function run() external {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address dcaToken = 0xb1599CDE32181f48f89683d3C5Db5C5D2C7C93cc;
        address gaugeHook = 0xb4f4Ad63BCc0102B10e6227236e569Dce0d97A80;
        
        // Get the deployer address
        address deployer = vm.addr(deployerPrivateKey);
        
        // Log initial balances
        uint256 initialETH = deployer.balance;
        uint256 initialDCA = IERC20(dcaToken).balanceOf(deployer);
        console.log("Initial balances:");
        console.log("ETH: %s", initialETH);
        console.log("DCA: %s", initialDCA);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Create pool key for ETH/DCA pool
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)), // ETH
            currency1: Currency.wrap(dcaToken),   // DCA
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG, 
            tickSpacing: 10,
            hooks: IHooks(gaugeHook)
        });

        // Set swap parameters
        bool zeroForOne = true; // true for ETH->DCA, false for DCA->ETH
        uint128 amountIn = 0.001e18; // 0.001 ETH
        uint128 minAmountOut = 49e17; // Set your minimum output amount

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
                amountOutMinimum: 0,
                hookData: bytes("")
            })
        );
        params[1] = abi.encode(Currency.wrap(address(0)), amountIn);
        params[2] = abi.encode(Currency.wrap(dcaToken), 0);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        // Execute the swap with ETH value
        uint256 deadline = block.timestamp + 20;
        ROUTER.execute{value: amountIn}(commands, inputs, deadline);

        vm.stopBroadcast();

        // Log final balances
        uint256 finalETH = deployer.balance;
        uint256 finalDCA = IERC20(dcaToken).balanceOf(deployer);
        console.log("\nFinal balances:");
        console.log("ETH: %s", finalETH);
        console.log("DCA: %s", finalDCA);

        // Calculate and log the exchange rate
        uint256 ethSpent = initialETH - finalETH;
        uint256 dcaReceived = finalDCA - initialDCA;
        console.log("\nSwap details:");
        console.log("ETH spent: %s", ethSpent);
        console.log("DCA received: %s", dcaReceived);
        console.log("Exchange rate: 1 ETH = %s DCA", (dcaReceived * 1e18) / ethSpent);
    }
} 