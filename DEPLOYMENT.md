# Super DCA Deployment Guide

This guide explains how to deploy Super DCA contracts with support for shared SuperDCATrade instances.

## Overview

Super DCA pools can now be deployed in two configurations:

1. **Standalone**: Each pool creates its own SuperDCATrade contract (default behavior)
2. **Shared**: Multiple pools reference a single SuperDCATrade contract for unified rewards tracking

## Prerequisites

- Foundry installed
- Environment variables set:
  - `PRIVATE_KEY`: Your deployment private key
  - `OPTIMISM_RPC_URL`: RPC endpoint for Optimism
  - `BASE_RPC_URL`: RPC endpoint for Base

## Deployment Scripts

### Standalone Deployment (Default)

Deploy pools with individual SuperDCATrade contracts:

```bash
# Deploy on Optimism (USDC->ETH)
forge script OptimismDeploy.s.sol --rpc-url $OPTIMISM_RPC_URL --broadcast --verify

# Deploy on Base (USDC->WBTC)
forge script BaseDeployERC20.s.sol --rpc-url $BASE_RPC_URL --broadcast --verify
```

### Shared SuperDCATrade Deployment

#### Step 1: Deploy SuperDCATrade

Deploy a SuperDCATrade contract that will be shared across multiple pools:

```bash
forge script DeploySuperDCATrade.s.sol --rpc-url $OPTIMISM_RPC_URL --broadcast --verify
```

Note the deployed address from the output.

#### Step 2: Deploy Pools with Existing SuperDCATrade

Set the SuperDCATrade address and deploy pools:

```bash
# Set the address from Step 1
export EXISTING_TRADE_ADDRESS=0x1234567890abcdef1234567890abcdef12345678

# Deploy first pool
forge script OptimismDeployWithExistingTrade.s.sol --rpc-url $OPTIMISM_RPC_URL --broadcast --verify

# Deploy additional pools (same or different networks)
forge script BaseDeployERC20WithExistingTradeImpl.s.sol --rpc-url $BASE_RPC_URL --broadcast --verify
```

## Constructor Changes

Both `SuperDCAPoolV1` and `SuperDCAPoolV1ERC20` now accept an additional constructor parameter:

```solidity
constructor(
    address payable _ops,
    address _router,
    address _poolManager,
    address _permit2,
    address _dcaTradeAddress  // New parameter
)
```

- **_dcaTradeAddress**: Address of existing SuperDCATrade contract
  - Use `address(0)` to create a new instance (backward compatible)
  - Use existing address to share SuperDCATrade across pools

## Benefits of Shared SuperDCATrade

1. **Unified Rewards**: All trades across pools contribute to the same NFT collection
2. **Simplified Tracking**: Single contract to monitor all user trades
3. **Reduced Deployment Costs**: Reuse existing SuperDCATrade instead of deploying new ones
4. **Better Analytics**: Consolidated trade data across multiple pools

## Environment Variables

Optional environment variables for shared deployment:

```bash
# SuperDCATrade address to use for new pools
export EXISTING_TRADE_ADDRESS=0x1234567890abcdef1234567890abcdef12345678
```

If `EXISTING_TRADE_ADDRESS` is not set, the deployment scripts will fall back to creating new SuperDCATrade instances.

## Verification

After deployment, verify contracts on block explorers:

```bash
# The deployment scripts include --verify flag for automatic verification
# Manual verification if needed:
forge verify-contract <CONTRACT_ADDRESS> <CONTRACT_NAME> --chain-id <CHAIN_ID>
```

## Example Deployment Flow

Complete example for setting up shared SuperDCATrade across multiple pools:

```bash
# 1. Deploy shared SuperDCATrade on Optimism
forge script DeploySuperDCATrade.s.sol --rpc-url $OPTIMISM_RPC_URL --broadcast --verify

# 2. Note the deployed address (e.g., 0xABC123...)
export EXISTING_TRADE_ADDRESS=0xABC123...

# 3. Deploy USDC->ETH pool on Optimism using shared SuperDCATrade
forge script OptimismDeployWithExistingTrade.s.sol --rpc-url $OPTIMISM_RPC_URL --broadcast --verify

# 4. Deploy USDC->WBTC pool on Base using same shared SuperDCATrade
forge script BaseDeployERC20WithExistingTradeImpl.s.sol --rpc-url $BASE_RPC_URL --broadcast --verify

# Result: Both pools share the same SuperDCATrade contract for unified tracking
```

## Troubleshooting

### Common Issues

1. **"Missing EXISTING_TRADE_ADDRESS"**: Set the environment variable or use standalone deployment
2. **"Invalid SuperDCATrade address"**: Ensure the address is correct and the contract is deployed
3. **"Network mismatch"**: SuperDCATrade must be deployed on the same network as the pool

### Contract Verification

If automatic verification fails, manually verify using:

```bash
forge verify-contract <ADDRESS> contracts/SuperDCAPoolV1.sol:SuperDCAPoolV1 --chain-id <CHAIN_ID>
```