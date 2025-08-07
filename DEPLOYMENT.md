# SuperDCATrade Address Configuration - Quick Start

This section provides a quick start guide for the new SuperDCATrade address configuration functionality that allows multiple SuperDCAPool deployments to share a single SuperDCATrade contract.

## Quick Start

### Option 1: Traditional Deployment (Backward Compatible)
```bash
# Deploy pool with its own SuperDCATrade (same as before)
forge script script/OptimismDeploy.s.sol --broadcast
```

### Option 2: Modular Deployment (Recommended for Multiple Pools)
```bash
# Step 1: Deploy SuperDCATrade separately
forge script script/DeploySuperDCATrade.s.sol --broadcast

# Step 2: Set the deployed address for subsequent pool deployments
export SUPER_DCA_TRADE_ADDRESS=<deployed_address>

# Step 3: Deploy multiple pools that reference the same SuperDCATrade
forge script script/OptimismDeploy.s.sol --broadcast
```

### Option 3: Complete Example Deployment
```bash
# Deploy SuperDCATrade + multiple pools in one script
forge script script/FullOptimismDeploy.s.sol --broadcast
```

## Key Benefits

- **Unified Trade Tracking**: All trades across pools tracked in one contract
- **Centralized NFT Management**: Single NFT collection for all pools  
- **Gas Efficiency**: Reuse existing contracts instead of deploying new ones
- **Backward Compatibility**: Existing deployment patterns unchanged

## Testing

Run the test suite to verify functionality:
```bash
forge test --match-contract SuperDCAPoolConstructorTest -v
```

Run the verification script:
```bash
forge script script/VerifyImplementation.s.sol -v
```

## Documentation

For complete documentation, see [SuperDCATrade Configuration Guide](./docs/SuperDCATrade-Configuration.md).