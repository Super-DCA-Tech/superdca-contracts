// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Deployers} from "v4-periphery/lib/v4-core/test/utils/Deployers.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import "v4-core/types/Currency.sol";
import "v4-core/types/PoolId.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";

contract SuperDCAPoolV1_UV4StateInitializerTest is Test, Deployers {
    mapping(Currency => MockERC20) private tokens;
    function setUp() public {
        //Deploy Uniswap V4

        deployFreshManagerAndRouters();
        //Deploy DCA Token
        //Deploy and mint inputToken and outputToken
    }
}

// function testFork_CannotInitializeTwice() public {
//     // First initialization happens in setUp()

//     // Setup initialization params again
//     address[] memory path = new address[](3);
//     path[0] = USDC;
//     path[1] = DCA;
//     path[2] = WETH;

//     uint24[] memory fees = new uint24[](2);
//     fees[0] = 500;
//     fees[1] = 500;

//     SuperDCAPoolV1.InitParams memory params = SuperDCAPoolV1.InitParams({
//         host: ISuperfluid(HOST_SUPERFLUID),
//         cfa: IConstantFlowAgreementV1(CFA_SUPERFLUID),
//         ida: IInstantDistributionAgreementV1(IDA_SUPERFLUID),
//         weth: IWETH(WETH),
//         wethx: ISuperToken(WETHX),
//         inputToken: ISuperToken(USDCX),
//         outputToken: ISuperToken(WETHX),
//         router: ISwapRouter(UNISWAP_ROUTER),
//         uniswapFactory: IUniswapV3Factory(UNISWAP_FACTORY),
//         uniswapPath: path,
//         poolFees: fees,
//         priceFeed: AggregatorV3Interface(ETH_USDC_FEED),
//         invertPrice: false,
//         registrationKey: "k1",
//         automate: payable(GELATO_AUTOMATE)
//     });

//     // Attempt to initialize again should revert
//     vm.expectRevert(SuperDCAPoolV1.AlreadyInitialized.selector);
//     pool.initialize(params);
// }
// function testFork_InitializeRevertsWithNonexistentPool() public {
//     // Deploy a new pool instance
//     vm.startPrank(AUTHORIZED_DEPLOYER, AUTHORIZED_DEPLOYER);
//     SuperDCAPoolV1 newPool = new SuperDCAPoolV1(payable(GELATO_AUTOMATE));

//     // Setup initialization params with invalid pool fee
//     address[] memory path = new address[](3);
//     path[0] = USDC;
//     path[1] = DCA;
//     path[2] = WETH;

//     uint24[] memory fees = new uint24[](2);
//     fees[0] = 3000; // Using 3000 bps fee which doesn't exist for this pool
//     fees[1] = 500;

//     SuperDCAPoolV1.InitParams memory params = SuperDCAPoolV1.InitParams({
//         host: ISuperfluid(HOST_SUPERFLUID),
//         cfa: IConstantFlowAgreementV1(CFA_SUPERFLUID),
//         ida: IInstantDistributionAgreementV1(IDA_SUPERFLUID),
//         weth: IWETH(WETH),
//         wethx: ISuperToken(WETHX),
//         inputToken: ISuperToken(USDCX),
//         outputToken: ISuperToken(WETHX),
//         router: ISwapRouter(UNISWAP_ROUTER),
//         uniswapFactory: IUniswapV3Factory(UNISWAP_FACTORY),
//         uniswapPath: path,
//         poolFees: fees,
//         priceFeed: AggregatorV3Interface(ETH_USDC_FEED),
//         invertPrice: false,
//         registrationKey: "k1",
//         automate: payable(GELATO_AUTOMATE)
//     });

//     // Attempt to initialize with nonexistent pool should revert
//     vm.expectRevert(SuperDCAPoolV1.PoolDoesNotExist.selector);
//     newPool.initialize(params);
//     vm.stopPrank();
// }

// function testFork_InitializeRevertsWithNonexistentGasPool() public {
//     // Deploy a new pool instance
//     vm.startPrank(AUTHORIZED_DEPLOYER, AUTHORIZED_DEPLOYER);
//     SuperDCAPoolV1 newPool = new SuperDCAPoolV1(payable(GELATO_AUTOMATE));

//     // Setup initialization params
//     address[] memory path = new address[](3);
//     path[0] = USDC;
//     path[1] = DCA;
//     path[2] = WETH;

//     uint24[] memory fees = new uint24[](2);
//     fees[0] = 500;
//     fees[1] = 500;

//     SuperDCAPoolV1.InitParams memory params = SuperDCAPoolV1.InitParams({
//         host: ISuperfluid(HOST_SUPERFLUID),
//         cfa: IConstantFlowAgreementV1(CFA_SUPERFLUID),
//         ida: IInstantDistributionAgreementV1(IDA_SUPERFLUID),
//         weth: IWETH(WETH),
//         wethx: ISuperToken(WETHX),
//         inputToken: ISuperToken(USDCX),
//         outputToken: ISuperToken(WETHX),
//         router: ISwapRouter(UNISWAP_ROUTER),
//         uniswapFactory: IUniswapV3Factory(UNISWAP_FACTORY),
//         uniswapPath: path,
//         poolFees: fees,
//         priceFeed: AggregatorV3Interface(ETH_USDC_FEED),
//         invertPrice: false,
//         registrationKey: "k1",
//         automate: payable(GELATO_AUTOMATE)
//     });

//     // Mock the Uniswap factory to return address(0) for the gas reimbursement pool
//     vm.mockCall(
//         UNISWAP_FACTORY,
//         abi.encodeWithSelector(
//             IUniswapV3Factory.getPool.selector,
//             WETH,
//             USDC,
//             500 // GELATO_GAS_POOL_FEE
//         ),
//         abi.encode(address(0))
//     );

//     // Attempt to initialize with nonexistent gas pool should revert
//     vm.expectRevert(SuperDCAPoolV1.PoolDoesNotExist.selector);
//     newPool.initialize(params);
//     vm.stopPrank();

//     // Clear the mock to not affect other tests
//     vm.clearMockedCalls();
// }
