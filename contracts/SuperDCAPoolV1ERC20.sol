// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.28;

// Superfluid imports
import {
  ISuperfluid,
  ISuperToken,
  ISuperAgreement,
  SuperAppDefinitions
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {IConstantFlowAgreementV1} from
  "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {IInstantDistributionAgreementV1} from
  "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IInstantDistributionAgreementV1.sol";
import {SuperAppBase} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";
import {ISETH} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/tokens/ISETH.sol";

// OpenZeppelin imports
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Uniswap imports
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PathKey} from "@uniswap/v4-periphery/src/libraries/PathKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";

// Chainlink imports
import {AggregatorV3Interface} from "@chainlink/contracts/interfaces/AggregatorV3Interface.sol";

// Gelato imports
import {AutomateTaskCreator} from "@gelato/contracts/integrations/AutomateTaskCreator.sol";
import {ModuleData, Module} from "@gelato/contracts/integrations/Types.sol";

// Local imports
import {IWETH} from "../contracts/interface/IWETH.sol";
import "./SuperDCATrade.sol";

// Uniswap V4 Swap mix-in
import {SuperDCASwap} from "./SuperDCASwap.sol";

// Staking mix-in
import {SuperDCAPoolStaking} from "./pool/SuperDCAPoolStaking.sol";

// Libs
import {FeeRetargetLib} from "./pool/libs/FeeRetargetLib.sol";
import {ShareMathLib} from "./pool/libs/ShareMathLib.sol";

import "forge-std/console.sol";

/// @title SuperDCAPoolV1
/// @notice A Superfluid app that allows users to swap between two tokens using a DCA strategy
/// @dev This contract is a mixin of SuperDCAPoolStaking and SuperDCASwap
/// @dev This contract only supports ERC20 tokens (e.g. USDC, USDT, etc.) to WETH swaps, output must
/// be WETH
contract SuperDCAPoolV1 is SuperAppBase, AutomateTaskCreator, SuperDCAPoolStaking, SuperDCASwap, Ownable {
  using SafeERC20 for ERC20;

  // --- Structs ---

  /// @notice Parameters used to initialize the pool
  struct InitParams {
    ISuperfluid host;
    IConstantFlowAgreementV1 cfa;
    IInstantDistributionAgreementV1 ida;
    IWETH weth;
    ISuperToken inputToken;
    ISuperToken outputToken;
    AggregatorV3Interface priceFeed;
    string registrationKey;
    address payable automate;
  }

  /// @notice Parameters needed to perform a shareholder update (i.e. a flow rate update)
  struct ShareholderUpdate {
    address shareholder; // The shareholder to update
    int96 currentFlowRate; // The current flow rate of the shareholder
    ISuperToken token; // The token to update the flow rate for
  }

  // --- State Variables ---

  // Superfluid Variables
  ISuperfluid internal host; // Superfluid host contract
  IConstantFlowAgreementV1 internal cfa; // The stored constant flow agreement class address
  IInstantDistributionAgreementV1 internal ida; // The stored instant dist. agreement class address

  // SuperDCA Pool Variables
  SuperDCATrade public dcaTrade;
  uint256 public lastDistributedAt; // The timestamp of the last distribution
  ISuperToken public inputToken; // e.g. USDCx
  ISuperToken public outputToken; // e.g. WBTCx
  address public underlyingInputToken; // e.g. USDC
  address public underlyingOutputToken; // e.g. WBTC
  IWETH public weth;
  uint32 public constant OUTPUT_INDEX = 0; // Superfluid IDA Index for outputToken's output pool
  uint256 public constant INTERVAL = 60_000; // The interval for gelato to check for execution
  uint256 public constant EXEC_FEE_SCALER = 1e18; // The scaler for the execution fee (1e18 = 100%)
  // TODO: make's minoutput 0 for simulation
  uint256 public constant RATE_TOLERANCE = 1e4; // The percentage to deviate from the oracle (basis
    // points)
  uint128 public constant SHARE_SCALER = 100_000; // The scaler to apply to the share of the
    // outputToken pool

  // Uniswap V4 Constants
  address constant GAUGE_HOOK_ADDRESS = 0xb4f4Ad63BCc0102B10e6227236e569Dce0d97A80;
  address constant USDC_ADDRESS = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
  address constant DCA_ADDRESS = 0xb1599CDE32181f48f89683d3C5Db5C5D2C7C93cc;
  address constant ETH_ADDRESS = address(0);
  address constant WBTC_ADDRESS = 0x4ac8bD1bDaE47beeF2D1c6Aa62229509b962Aa0d;

  PoolKey DCA_USDC_KEY = PoolKey({
    currency0: Currency.wrap(USDC_ADDRESS),
    currency1: Currency.wrap(DCA_ADDRESS),
    fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
    tickSpacing: 10,
    hooks: IHooks(GAUGE_HOOK_ADDRESS)
  });

  PoolKey DCA_ETH_KEY = PoolKey({
    currency0: Currency.wrap(ETH_ADDRESS),
    currency1: Currency.wrap(DCA_ADDRESS),
    fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
    tickSpacing: 10,
    hooks: IHooks(GAUGE_HOOK_ADDRESS)
  });

  PoolKey DCA_WBTC_KEY = PoolKey({
    currency0: Currency.wrap(WBTC_ADDRESS),
    currency1: Currency.wrap(DCA_ADDRESS),
    fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
    tickSpacing: 60,
    hooks: IHooks(GAUGE_HOOK_ADDRESS)
  });

  // Chainlink Variables
  AggregatorV3Interface public priceFeed; // Chainlink price feed for the inputToken/outputToken

  // Gelato task variables
  bytes32 public taskId;
  uint256 public gelatoFeeShare = 1e16; // number of basis points gelato takes for executing the
    // task
  uint256 public distributionInterval = 4 hours; // the interval to retarget to by adjusting fee
    // share

  // Constants for fee retargeting calculations
  uint256 public constant DECIMALS = 18;
  uint256 public constant MIN_FEE_SHARE = 1; // 1 wei lower bound
  uint256 public constant MAX_FEE_SHARE = 1e16; // 1% = 0.01 = 1e16 (with 18 decimals)
  uint256 public constant GROWTH_FACTOR = 2; // Simple multiplier of 2
  uint256 public constant MAX_HOURS_PAST_INTERVAL = 10; // Maximum hours past the interval to
    // consider

  // New state variables
  uint256 public baseFeeShare;
  uint256 public maxFeeHalvings;

  // --- Events ---
  event Swap(
    uint256 inputAmount, uint256 outputAmount, uint256 oraclePrice, uint256 fee, address feePayer
  );
  event UpdateGelatoFeeShare(uint256 newGelatoFee);
  event RefundedUninvestedAmount(address shareholder, uint256 uninvestAmount);
  event ErrorRefundingUninvestedAmount(address shareholder, uint256 uninvestAmount);
  event UpdateMaxFeeHalvings(uint256 newMaxFeeHalvings);

  // --- Errors ---
  error AlreadyInitialized();
  error InvalidHost();
  error InvalidToken();
  error PoolDoesNotExist();
  error NotClosable();

  // --- Constructor ---
  constructor(address payable _ops, address _router, address _poolManager, address _permit2)
    AutomateTaskCreator(_ops)
    SuperDCASwap(_router, _poolManager, _permit2)
  {
    // Deploy Trade for trade tracking
    dcaTrade = new SuperDCATrade();

    // Initialize fee related parameters
    baseFeeShare = gelatoFeeShare; // establish baseline
    maxFeeHalvings = 10; // default maximum halvings (~1% / 2^10 = 0.0009765625%)
  }

  // --- Initialization Functions ---
  function initialize(InitParams memory params) public {
    if (address(inputToken) != address(0)) revert AlreadyInitialized();

    // Initialize Superfluid
    host = params.host;
    cfa = params.cfa;
    ida = params.ida;

    uint256 _configWord = SuperAppDefinitions.APP_LEVEL_FINAL;

    if (bytes(params.registrationKey).length > 0) {
      host.registerAppWithKey(_configWord, params.registrationKey);
    } else {
      host.registerApp(_configWord);
    }

    _createGelatoTask();
    weth = params.weth;
    _initializePool(params.inputToken, params.outputToken);
    priceFeed = params.priceFeed;
  }

  function _createGelatoTask() internal {
    // Create a timed interval task with Gelato Network
    bytes memory execData = abi.encodeCall(this.distribute, ("", false));
    ModuleData memory moduleData = ModuleData({modules: new Module[](2), args: new bytes[](2)});
    moduleData.modules[0] = Module.PROXY;
    moduleData.modules[1] = Module.TRIGGER;
    moduleData.args[0] = _proxyModuleArg();
    // solhint-disable-next-line not-rely-on-time
    moduleData.args[1] = _timeTriggerModuleArg(uint128(block.timestamp), uint128(INTERVAL));
    taskId = _createTask(address(this), execData, moduleData, ETH);
  }

  function _initializePool(ISuperToken _inputToken, ISuperToken _outputToken) internal {
    inputToken = _inputToken;
    outputToken = _outputToken;
    // solhint-disable-next-line not-rely-on-time
    lastDistributedAt = block.timestamp;
    underlyingOutputToken = _getUnderlyingToken(outputToken);
    underlyingInputToken = _getUnderlyingToken(inputToken);

    // Make the output IDA pool
    _createIndex(OUTPUT_INDEX, outputToken);

    // Approve upgrading underlying outputTokens if its not a supertoken
    ERC20(underlyingOutputToken).safeIncreaseAllowance(address(outputToken), type(uint256).max);
  }

  // --- Core Distribution Logic ---
  function distribute(bytes memory ctx, bool ignoreGasReimbursement)
    public
    payable
    returns (bytes memory newCtx)
  {
    newCtx = ctx;
    uint256 inputTokenAmount = inputToken.balanceOf(address(this));

    // If there is no inputToken to distribute, then return immediately
    if (inputTokenAmount == 0) return newCtx;

    // Downgrade tokens and get underlying balance
    uint256 underlyingBalance = _downgradeInputTokens(inputTokenAmount);

    // Update the fee share for this distribution
    gelatoFeeShare = getExecutionFeeShare(gelatoFeeShare);
    emit UpdateGelatoFeeShare(gelatoFeeShare);

    // Record when the last distribution happened for other calculations
    // solhint-disable-next-line not-rely-on-time
    lastDistributedAt = block.timestamp;

    // Record the latest price for the inputToken/outputToken pair
    uint256 latestPrice = getLatestPrice();

    // Execute the swap
    uint256 outputTokenAmount = _swap(underlyingBalance);

    // Calculate the portion of the output that will go toward the fee (in ETH terms)
    // e.g. If gelatoFeeShare = 1e16 (1%) and we received 100 ETH worth of output,
    // the executor is entitled to 1 ETH.
    uint256 maxFeeEthAmount = (outputTokenAmount * gelatoFeeShare) / EXEC_FEE_SCALER;

    // Support skipping gas reimbursement in edge cases
    uint256 fee = 0;
    address feeToken = address(0);
    if (!ignoreGasReimbursement) {
      // Get the fee details from Gelato Ops
      (fee, feeToken) = _getFeeDetails();

      // If the fee is greater than 0 and less than the max fee amount, reimburse Gelato
      if (fee > 0 && fee < maxFeeEthAmount) {
        _transfer(fee, feeToken);
      }
    } else if (currentExecutor != address(0)) {
      // Send whatever fee share of outputTokens have accumulated to the staked executor
      payable(currentExecutor).transfer(maxFeeEthAmount);
    }

    // Emit swap event for performance tracking purposes
    emit Swap(
      inputTokenAmount,
      outputTokenAmount,
      latestPrice,
      fee > 0 ? fee : maxFeeEthAmount,
      fee > 0 ? address(0) : currentExecutor
    );

    // Handle token upgrading (e.g. WBTC -> WBTCx)
    _handleTokenUpgrade();

    // Deposit all ETH currently held by the contract into WETH so it is tracked
    weth.deposit{value: address(this).balance}();

    // Update outputTokenAmount to include any remaining balance from previous rounds
    outputTokenAmount = outputToken.balanceOf(address(this));

    // If there is no outputToken to distribute, then return
    if (outputTokenAmount == 0) return newCtx;

    // Distribute outputToken via IDA
    (outputTokenAmount,) =
      ida.calculateDistribution(outputToken, address(this), OUTPUT_INDEX, outputTokenAmount);

    newCtx = _idaDistribute(OUTPUT_INDEX, uint128(outputTokenAmount), outputToken, newCtx);

    return newCtx;
  }

  function _downgradeInputTokens(uint256 amount) internal returns (uint256) {
    if (underlyingInputToken != address(inputToken) && underlyingInputToken != address(weth)) {
      inputToken.downgrade(amount);
    } else if (underlyingInputToken == address(weth)) {
      ISETH(address(inputToken)).downgradeToETH(amount);
      weth.deposit{value: address(this).balance}();
    }
    return ERC20(underlyingInputToken).balanceOf(address(this));
  }

  function _swap(uint256 amount) internal returns (uint256) {
    // Cast amount to uint128 for the swap function
    uint128 amountIn = uint128(amount);
    uint128 minAmountOut = 0; // Same as original implementation

    // Create path based on tokens
    PathKey[] memory path = new PathKey[](2);

    // Step 1: inputToken -> DCA
    path[0] = PathKey({
      intermediateCurrency: Currency.wrap(DCA_ADDRESS),
      fee: DCA_USDC_KEY.fee,
      tickSpacing: DCA_USDC_KEY.tickSpacing,
      hooks: DCA_USDC_KEY.hooks,
      hookData: bytes("")
    });

    // Step 2: DCA -> outputToken
    path[1] = PathKey({
      intermediateCurrency: Currency.wrap(WBTC_ADDRESS),
      fee: DCA_WBTC_KEY.fee,
      tickSpacing: DCA_WBTC_KEY.tickSpacing,
      hooks: DCA_WBTC_KEY.hooks,
      hookData: bytes("")
    });

    // Define input currency
    Currency currencyIn = Currency.wrap(underlyingInputToken);

    // Approve tokens for Permit2
    _approveTokenWithPermit2(underlyingInputToken, uint128(amountIn), uint48(block.timestamp + 300));

    // Execute the swap using the inherited swapExactInput function
    return _swapExactInput(currencyIn, path, amountIn, minAmountOut);
  }

  function _handleTokenUpgrade() internal {
    // This will only ever be WBTC -> WBTCx, but will work for any ERC20
    outputToken.upgrade(
      ERC20(underlyingOutputToken).balanceOf(address(this))
        * (10 ** (18 - ERC20(underlyingOutputToken).decimals()))
    );
  }

  function getLatestPrice() public view returns (uint256) {
    if (address(priceFeed) == address(0)) return 0;

    (, int256 price,,,) = priceFeed.latestRoundData();
    return uint256(price);
  }

  // --- Superfluid App Callbacks ---
  function beforeAgreementCreated(
    ISuperToken _superToken,
    address _agreementClass,
    bytes32, //_agreementId,
    bytes calldata, // _agreementData,
    bytes calldata _ctx
  ) external view virtual override returns (bytes memory _cbdata) {
    _onlyHost();

    // Make sure the agreement is either:
    // - inputToken and CFAv1
    // - outputToken and IDAv1
    if (
      !(_isInputToken(_superToken) && _isCFAv1(_agreementClass))
        && !(_isOutputToken(_superToken) && _isIDAv1(_agreementClass))
    ) revert InvalidToken();

    // If this isn't a CFA Agreement class, return the context and be done
    if (!_isCFAv1(_agreementClass)) return _ctx;
  }

  function afterAgreementCreated(
    ISuperToken _superToken,
    address _agreementClass,
    bytes32, //_agreementId,
    bytes calldata _agreementData,
    bytes calldata, //_cbdata,
    bytes calldata _ctx
  ) external virtual override returns (bytes memory _newCtx) {
    _onlyHost();
    if (!_isInputToken(_superToken) || !_isCFAv1(_agreementClass)) return _ctx;

    _newCtx = _ctx;

    if (_shouldDistribute()) _newCtx = distribute(_newCtx, true);

    (address _shareholder, int96 _flowRate,) = _getShareholderInfo(_agreementData, _superToken);

    ShareholderUpdate memory _shareholderUpdate =
      ShareholderUpdate(_shareholder, _flowRate, _superToken);
    _newCtx = _updateShareholder(_newCtx, _shareholderUpdate);

    // Get the current index value for dcatrade tracking
    uint256 _indexValue = getIDAIndexValue();

    // Get IDA shares for this user for dcatrade tracking
    (,, uint128 _units,) = getIDAShares(_shareholder);

    // Mint the shareholder an NFT to track their trade
    dcaTrade.startTrade(_shareholder, _flowRate, _indexValue, _units);
  }

  function beforeAgreementUpdated(
    ISuperToken _superToken,
    address _agreementClass,
    bytes32, //_agreementId,
    bytes calldata _agreementData,
    bytes calldata _ctx
  ) external view virtual override returns (bytes memory _cbdata) {
    // Only allow the Superfluid host to call this function
    _onlyHost();

    // If the agreement is not a CFAv1 agreement, then return the context
    if (!_isInputToken(_superToken) || !_isCFAv1(_agreementClass)) return _ctx;

    // Get the stakeholders current flow rate and save it in cbData
    (, int96 _flowRate,) = _getShareholderInfo(_agreementData, _superToken);

    // Encode the rate for use in afterAgreementUpdated
    _cbdata = abi.encode(_flowRate);
  }

  function afterAgreementUpdated(
    ISuperToken _superToken,
    address _agreementClass,
    bytes32, //_agreementId,
    bytes calldata _agreementData,
    bytes calldata, // _cbdata,
    bytes calldata _ctx
  ) external virtual override returns (bytes memory _newCtx) {
    _onlyHost();

    // If the agreement is not a CFAv1 agreement, return the context
    if (!_isInputToken(_superToken) || !_isCFAv1(_agreementClass)) return _ctx;

    // Copy the argment context to a new context return variable
    _newCtx = _ctx;

    // Get the caller's address and current flow rate from the agreement data
    (address _shareholder, int96 _flowRate,) = _getShareholderInfo(_agreementData, _superToken);

    // Before updating the shares, check if the distribution should be triggered
    // Trigger the distribution flushes the system before changing share allocations
    // This may no longer be needed
    if (_shouldDistribute()) _newCtx = distribute(_newCtx, true);

    // Get the current index value for dcatrade tracking
    uint256 _indexValue = getIDAIndexValue();

    // End the trade for this shareholder
    dcaTrade.endTrade(_shareholder, _indexValue, 0);

    // Build the shareholder update parameters and update the shareholder
    ShareholderUpdate memory _shareholderUpdate =
      ShareholderUpdate(_shareholder, _flowRate, _superToken);

    _newCtx = _updateShareholder(_newCtx, _shareholderUpdate);

    // Get IDA shares for this user for dcatrade tracking
    (,, uint128 _units,) = getIDAShares(_shareholder);

    // Mint the shareholder an NFT to track their trade
    dcaTrade.startTrade(_shareholder, _flowRate, _indexValue, _units);
  }

  function beforeAgreementTerminated(
    ISuperToken _superToken,
    address _agreementClass,
    bytes32, //_agreementId,
    bytes calldata _agreementData,
    bytes calldata _ctx
  ) external view virtual override returns (bytes memory _cbdata) {
    _onlyHost();
    if (!_isInputToken(_superToken) || !_isCFAv1(_agreementClass)) return _ctx;

    (, int96 _flowRateMain, uint256 _timestamp) = _getShareholderInfo(_agreementData, _superToken);

    uint256 _uinvestAmount = _calcUserUninvested(
      _timestamp,
      uint256(uint96(_flowRateMain)),
      // Select the correct lastDistributedAt for this _superToken
      lastDistributedAt
    );

    _cbdata = abi.encode(_uinvestAmount);
  }

  function afterAgreementTerminated(
    ISuperToken _superToken,
    address _agreementClass,
    bytes32, //_agreementId,
    bytes calldata _agreementData,
    bytes calldata _cbdata, //_cbdata,
    bytes calldata _ctx
  ) external virtual override returns (bytes memory _newCtx) {
    // Only allow the Superfluid host to call this function
    _onlyHost();

    // If the agreement is not a CFAv1 agreement, return the context
    if (!_isInputToken(_superToken) || !_isCFAv1(_agreementClass)) return _ctx;

    _newCtx = _ctx;

    // Get the caller's address and current flow rate from the agreement data
    (address _shareholder,) = abi.decode(_agreementData, (address, address));

    // Get the current index value for dcatrade tracking
    uint256 _indexValue = getIDAIndexValue();

    // Decode the cbData to get the caller's previous flow rate, set in beforeAgreementTerminated
    uint256 _uninvestAmount = abi.decode(_cbdata, (uint256));

    // End the trade for this shareholder
    dcaTrade.endTrade(_shareholder, _indexValue, _uninvestAmount);

    // Build the shareholder update parameters and update the shareholder
    ShareholderUpdate memory _shareholderUpdate = ShareholderUpdate(_shareholder, 0, _superToken);

    _newCtx = _updateShareholder(_newCtx, _shareholderUpdate);

    // Refund the unswapped amount back to the person who started the stream
    // Methods in the terminate callback can not revert, hence the try-catch
    try _superToken.transferFrom(address(this), _shareholder, _uninvestAmount) {
      // solhint-disable-next-line no-empty-blocks
      emit RefundedUninvestedAmount(_shareholder, _uninvestAmount);
    } catch {
      // In case of any problems here, log the error for record keeping and continue
      emit ErrorRefundingUninvestedAmount(_shareholder, _uninvestAmount);
    }
  }

  // --- Superfluid Agreement Helper Functions ---
  function _idaDistribute(
    uint32 _index,
    uint128 _distAmount,
    ISuperToken _distToken,
    bytes memory _ctx
  ) internal returns (bytes memory _newCtx) {
    _newCtx = _ctx;
    if (_newCtx.length == 0) {
      // No context provided
      host.callAgreement(
        ida,
        abi.encodeWithSelector(
          ida.distribute.selector,
          _distToken,
          _index,
          _distAmount,
          new bytes(0) // placeholder ctx
        ),
        new bytes(0) // user data
      );
    } else {
      (_newCtx,) = host.callAgreementWithContext(
        ida,
        abi.encodeWithSelector(
          ida.distribute.selector,
          _distToken,
          _index,
          _distAmount,
          new bytes(0) // placeholder ctx
        ),
        new bytes(0), // user data
        _newCtx
      );
    }
  }

  function _createIndex(uint256 index, ISuperToken distToken) internal {
    host.callAgreement(
      ida,
      abi.encodeWithSelector(
        ida.createIndex.selector,
        distToken,
        index,
        new bytes(0) // placeholder ctx
      ),
      new bytes(0) // user data
    );
  }

  function _updateSubscriptionWithContext(
    bytes memory ctx,
    uint256 index,
    address subscriber,
    uint128 shares,
    ISuperToken distToken
  ) internal returns (bytes memory newCtx) {
    newCtx = ctx;
    (newCtx,) = host.callAgreementWithContext(
      ida,
      abi.encodeWithSelector(
        ida.updateSubscription.selector, distToken, index, subscriber, shares, new bytes(0)
      ),
      new bytes(0), // user data
      newCtx
    );
  }

  function _isCFAv1(address _agreementClass) internal view returns (bool) {
    return ISuperAgreement(_agreementClass).agreementType()
      == keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");
  }

  function _isIDAv1(address _agreementClass) internal view returns (bool) {
    return ISuperAgreement(_agreementClass).agreementType()
      == keccak256("org.superfluid-finance.agreements.InstantDistributionAgreement.v1");
  }

  function _onlyHost() internal view {
    if (msg.sender != address(host)) revert InvalidHost();
  }

  // --- Shareholder & Fee Logic ---
  function _updateShareholder(bytes memory _ctx, ShareholderUpdate memory _shareholderUpdate)
    internal
    returns (bytes memory _newCtx)
  {
    _newCtx = _ctx;

    _shareholderUpdate.token = outputToken;

    uint128 userShares = ShareMathLib.flowRateToShares(_shareholderUpdate.currentFlowRate);

    _newCtx = _updateSubscriptionWithContext(
      _newCtx, OUTPUT_INDEX, _shareholderUpdate.shareholder, userShares, outputToken
    );
  }

  function _getShareholderInfo(bytes calldata _agreementData, ISuperToken _superToken)
    internal
    view
    returns (address _shareholder, int96 _flowRate, uint256 _timestamp)
  {
    (_shareholder,) = abi.decode(_agreementData, (address, address));
    (_timestamp, _flowRate,,) = cfa.getFlow(_superToken, _shareholder, address(this));
  }

  function _getShareAllocations(ShareholderUpdate memory _shareholderUpdate)
    internal
    pure
    returns (uint128 userShares)
  {
    // The user's shares will always be their current flow rate
    userShares = ShareMathLib.flowRateToShares(_shareholderUpdate.currentFlowRate);
  }

  function _calcUserUninvested(uint256 prevUpdateTimestamp, uint256 flowRate, uint256 lastDist)
    internal
    view
    returns (uint256)
  {
    return ShareMathLib.calcUserUninvested(prevUpdateTimestamp, flowRate, lastDist);
  }

  function getExecutionFeeShare(uint256 currentFeeShare) public view returns (uint256) {
    uint256 minFeeShareDynamic = baseFeeShare / (2 ** maxFeeHalvings);
    if (minFeeShareDynamic < MIN_FEE_SHARE) {
      minFeeShareDynamic = MIN_FEE_SHARE;
    }
    return FeeRetargetLib.adjustFeeShare(
      currentFeeShare,
      lastDistributedAt,
      distributionInterval,
      minFeeShareDynamic,
      MAX_FEE_SHARE
    );
  }

  // --- Getter / View Functions ---
  function _isInputToken(ISuperToken _superToken) internal view returns (bool) {
    return address(_superToken) == address(inputToken);
  }

  function _isOutputToken(ISuperToken _superToken) internal view returns (bool) {
    return address(_superToken) == address(outputToken);
  }

  function _shouldDistribute() internal view returns (bool) {
    // TODO: Might no longer be required
    (,, uint128 _totalUnitsApproved, uint128 _totalUnitsPending) =
      ida.getIndex(outputToken, address(this), OUTPUT_INDEX);
    return _totalUnitsApproved + _totalUnitsPending > 0;
  }

  function _getUnderlyingToken(ISuperToken _token) internal view returns (address) {
    // Will NOT work with ETHx
    address underlyingToken = _token.getUnderlyingToken();

    // If the underlying token is 0x0, then the token is a supertoken
    if (address(underlyingToken) == address(0)) return address(_token);

    return underlyingToken;
  }

  function getNextDistributionTime(uint256 gasPrice, uint256 gasLimit, uint256 tokenToWethRate)
    public
    view
    returns (uint256)
  {
    int96 netFlow = cfa.getNetFlow(inputToken, address(this));
    if (netFlow == 0) return type(uint256).max;

    uint256 inflowRate = uint256(int256(netFlow)) / (10 ** 9);
    uint256 tokenAmount = gasPrice * gasLimit * tokenToWethRate;
    uint256 timeToDistribute = (tokenAmount / inflowRate) / (10 ** 9);
    return lastDistributedAt + timeToDistribute;
  }

  function getIDAShares(address _streamer)
    public
    view
    returns (bool _exist, bool _approved, uint128 _units, uint256 _pendingDistribution)
  {
    (_exist, _approved, _units, _pendingDistribution) =
      ida.getSubscription(outputToken, address(this), OUTPUT_INDEX, _streamer);
  }

  function getIDAIndexValue() public view returns (uint256) {
    (, uint256 _indexValue,,) = ida.getIndex(outputToken, address(this), OUTPUT_INDEX);
    return _indexValue;
  }

  function getTradeInfo(address _trader, uint256 _tradeIndex)
    public
    view
    returns (SuperDCATrade.Trade memory trade)
  {
    trade = dcaTrade.getTradeInfo(_trader, _tradeIndex);
  }

  function getLatestTrade(address _trader) public view returns (SuperDCATrade.Trade memory trade) {
    if (dcaTrade.tradeCountsByUser(_trader) > 0) trade = dcaTrade.getLatestTrade(_trader);
    else trade = SuperDCATrade.Trade(0, 0, 0, 0, 0, 0, 0, 0);
  }

  function getTradeCount(address _trader) public view returns (uint256 count) {
    count = dcaTrade.tradeCountsByUser(_trader);
  }

  // --- External Interaction Functions ---
  function closeStream(address streamer, ISuperToken token) public {
    // Only closable iff their balance is less than 8 hours of streaming
    (, int96 streamerFlowRate,,) = cfa.getFlow(token, streamer, address(this));
    if (int256(token.balanceOf(streamer)) > streamerFlowRate * 8 hours) revert NotClosable();

    // Close the streamers stream
    // Does this trigger before/afterAgreementTerminated
    host.callAgreement(
      cfa,
      abi.encodeWithSelector(
        cfa.deleteFlow.selector, 
        token,
        streamer,
        address(this),
        new bytes(0) // placeholder
      ),
      "0x"
    );
  }

  // --- Fallback Function ---
  receive() external payable override {}

  // --- Admin Functions ---
  function setGelatoFeeShare(uint256 newGelatoFee) public onlyOwner {
    gelatoFeeShare = newGelatoFee;
    baseFeeShare = newGelatoFee; // reset baseline when manually set
    emit UpdateGelatoFeeShare(newGelatoFee);
  }

  function setMaxFeeHalvings(uint256 newMaxFeeHalvings) public onlyOwner {
    maxFeeHalvings = newMaxFeeHalvings;
    emit UpdateMaxFeeHalvings(newMaxFeeHalvings);
  }
}
