// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

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

/// @title SwapExecutor
/// @notice Encapsulates the full ETH ➜ DCA ➜ USDC ➜ ETH swap sequence so that
///         a caller can perform the whole flow via a single function call.
contract SwapExecutor {
    // ========================= Constants =========================

    IUniversalRouter public constant ROUTER =
        IUniversalRouter(0x851116D9223fabED8E56C0E6b8Ad0c31d98B3507);
    IPermit2 public constant PERMIT2 =
        IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    address public constant USDC_TOKEN =
        0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    address public constant DCA_TOKEN =
        0xb1599CDE32181f48f89683d3C5Db5C5D2C7C93cc;
    address public constant GAUGE_HOOK =
        0xb4f4Ad63BCc0102B10e6227236e569Dce0d97A80;

    // ========================= Pool keys =========================

    PoolKey public ETH_DCA_POOL_KEY = PoolKey({
        currency0: Currency.wrap(address(0)), // ETH
        currency1: Currency.wrap(DCA_TOKEN),
        fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
        tickSpacing: 10,
        hooks: IHooks(GAUGE_HOOK)
    });

    PoolKey public DCA_USDC_POOL_KEY = PoolKey({
        currency0: Currency.wrap(USDC_TOKEN),
        currency1: Currency.wrap(DCA_TOKEN),
        fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
        tickSpacing: 10,
        hooks: IHooks(GAUGE_HOOK)
    });

    PoolKey public USDC_ETH_POOL_KEY = PoolKey({
        currency0: Currency.wrap(address(0)), // ETH
        currency1: Currency.wrap(USDC_TOKEN),
        fee: 500,
        tickSpacing: 10,
        hooks: IHooks(address(0))
    });

    // allow router to send ETH back after swaps
    receive() external payable {}

    // ========================= Internal helpers =========================

    function _approveTokenWithPermit2(
        address token,
        uint160 amount,
        uint48 expiration
    ) internal {
        // Approve Permit2 to pull tokens from this contract first – only once is
        // needed because we use the max uint.
        IERC20(token).approve(address(PERMIT2), type(uint256).max);
        // Authorise the Universal Router via Permit2 for the given amount.
        PERMIT2.approve(token, address(ROUTER), amount, expiration);
    }

    function _prepareSwapPath()
        internal
        view
        returns (PathKey[] memory path)
    {
        path = new PathKey[](2);
        // 1️⃣ ETH ➜ DCA
        path[0] = PathKey({
            intermediateCurrency: Currency.wrap(DCA_TOKEN),
            fee: ETH_DCA_POOL_KEY.fee,
            tickSpacing: ETH_DCA_POOL_KEY.tickSpacing,
            hooks: ETH_DCA_POOL_KEY.hooks,
            hookData: bytes("")
        });
        // 2️⃣ DCA ➜ USDC
        path[1] = PathKey({
            intermediateCurrency: Currency.wrap(USDC_TOKEN),
            fee: DCA_USDC_POOL_KEY.fee,
            tickSpacing: DCA_USDC_POOL_KEY.tickSpacing,
            hooks: DCA_USDC_POOL_KEY.hooks,
            hookData: bytes("")
        });
    }

    function _prepareRouterExecuteParams(
        PathKey[] memory path,
        uint128 amountIn
    )
        internal
        view
        returns (bytes memory commands, bytes[] memory inputs)
    {
        // Only one V4_SWAP command is needed for the multi-hop path.
        commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        inputs = new bytes[](1);

        // Sequence of V4 router actions for multi-hop exact-in swap.
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputParams({
                currencyIn: Currency.wrap(address(0)), // ETH in
                path: path,
                amountIn: amountIn,
                amountOutMinimum: 0 // for simplicity
            })
        );
        // settle ETH spent
        params[1] = abi.encode(Currency.wrap(address(0)), amountIn);
        // take all USDC out
        params[2] = abi.encode(Currency.wrap(USDC_TOKEN), 0);

        inputs[0] = abi.encode(actions, params);
    }

    // ========================= Public API =========================

    /// @notice Executes ETH ➜ DCA ➜ USDC and (optionally) USDC ➜ ETH, then
    ///         returns all resulting assets to the caller.
    /// @param amountInETH Amount of ETH to start the flow with.
    function execute(uint128 amountInETH) external payable {
        require(msg.value == amountInETH, "SwapExecutor: wrong msg.value");
        address caller = msg.sender;

        // --- pre-swap balances ---
        uint256 initialETH = caller.balance + msg.value; // balance before transfer
        uint256 initialDCA = IERC20(DCA_TOKEN).balanceOf(caller);
        uint256 initialUSDC = IERC20(USDC_TOKEN).balanceOf(caller);

        console.log("Initial balances (caller):");
        console.log("ETH: %s", initialETH);
        console.log("DCA: %s", initialDCA);
        console.log("USDC: %s", initialUSDC);

        // === First swap: ETH ➜ DCA ➜ USDC ===
        PathKey[] memory path = _prepareSwapPath();
        (bytes memory commands, bytes[] memory inputs) = _prepareRouterExecuteParams(path, amountInETH);

        ROUTER.execute{value: amountInETH}(commands, inputs, block.timestamp + 20);

        uint256 usdcReceived = IERC20(USDC_TOKEN).balanceOf(address(this));
        console.log("USDC received from first swap: %s", usdcReceived);

        // === Second swap: USDC ➜ ETH ===
        if (usdcReceived > 0) {
            console.log("Attempting second swap: USDC to ETH...");
            _approveTokenWithPermit2(
                USDC_TOKEN,
                uint160(usdcReceived),
                uint48(block.timestamp + 20)
            );

            bytes memory commandsSwap2 = abi.encodePacked(uint8(Commands.V4_SWAP));
            bytes[] memory inputsSwap2 = new bytes[](1);

            bytes memory actionsSwap2 = abi.encodePacked(
                uint8(Actions.SWAP_EXACT_IN_SINGLE),
                uint8(Actions.SETTLE_ALL),
                uint8(Actions.TAKE_ALL)
            );

            bytes[] memory paramsSwap2 = new bytes[](3);
            paramsSwap2[0] = abi.encode(
                IV4Router.ExactInputSingleParams({
                    poolKey: USDC_ETH_POOL_KEY,
                    zeroForOne: false,
                    amountIn: uint128(usdcReceived),
                    amountOutMinimum: 0,
                    hookData: bytes("")
                })
            );
            paramsSwap2[1] = abi.encode(
                Currency.wrap(USDC_TOKEN),
                uint128(usdcReceived)
            );
            paramsSwap2[2] = abi.encode(Currency.wrap(address(0)), 0);

            inputsSwap2[0] = abi.encode(actionsSwap2, paramsSwap2);

            ROUTER.execute(commandsSwap2, inputsSwap2, block.timestamp + 20);
            console.log("Second swap (USDC to ETH) executed.");
        } else {
            console.log(
                "Skipping second swap: No USDC received from the first swap."
            );
        }

        // return all assets held by this contract to the caller
        _returnFunds(caller);

        // --- post-swap balances ---
        uint256 finalETH = caller.balance;
        uint256 finalDCA = IERC20(DCA_TOKEN).balanceOf(caller);
        uint256 finalUSDC = IERC20(USDC_TOKEN).balanceOf(caller);

        console.log("Final balances (caller):");
        console.log("ETH: %s", finalETH);
        console.log("DCA: %s", finalDCA);
        console.log("USDC: %s", finalUSDC);

        // Exchange-rate info for the first hop
        uint256 netUsdcChange = finalUSDC - initialUSDC;
        if (netUsdcChange > 0 && amountInETH > 0) {
            console.log(
                "Exchange rate (ETH -> USDC, first swap): 1 ETH = %s USDC",
                (netUsdcChange * 1 ether) / amountInETH
            );
        }

        // === Net ETH P/L ===
        if (finalETH > initialETH) {
            console.log("Net ETH gained: %s", finalETH - initialETH);
        } else if (finalETH < initialETH) {
            console.log("Net ETH lost: %s", initialETH - finalETH);
        } else {
            console.log("No net ETH change.");
        }
    }

    // ========================= Internal utils =========================

    function _returnFunds(address to) internal {
        uint256 ethBal = address(this).balance;
        if (ethBal > 0) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool ok, ) = to.call{value: ethBal}("");
            require(ok, "ETH transfer failed");
        }

        uint256 dcaBal = IERC20(DCA_TOKEN).balanceOf(address(this));
        if (dcaBal > 0) {
            IERC20(DCA_TOKEN).transfer(to, dcaBal);
        }

        uint256 usdcBal = IERC20(USDC_TOKEN).balanceOf(address(this));
        if (usdcBal > 0) {
            IERC20(USDC_TOKEN).transfer(to, usdcBal);
        }
    }
} 