# Scripts for Sepolia 

## Deployed Contracts
This is a summary of the contracts that were deployed with the scripts in this directory. 

| Contract Name | Contract Address | Deployment Script |
|---------------|------------------|-------------------|
| Deployer | 0xC07E21c78d6Ad0917cfCBDe8931325C392958892 | NA |
| Super DCA Token | 0x26AE4b2b875Ec1DC6e4FDc3e9C74E344c3b43A54 | NA |
| fUSDC>>fDAI Pool | 0x399Bee1893F920B9c6aaE5b495dcbaEDA3C797d0 | `./deploy_dca_pool.ts` | 

## Gelato Task Ids
* fUSDC>>fDAI taskId: https://app.gelato.network/functions/task/0x6dc402b5e2f2f2ff780e3d6cd0ff9a8c4add69dd6583d119e844eeee422fa033:11155111


### fUSDC>>fDAI
```shell
INPUT_TOKEN=0xb598e6c621618a9f63788816ffb50ee2862d443b \
INPUT_TOKEN_UNDERLYING=0xe72f289584eDA2bE69Cfe487f4638F09bAc920Db \
OUTPUT_TOKEN=0x9ce2062b085a2268e8d769ffc040f6692315fd2c \
OUTPUT_TOKEN_UNDERLYING=0x4E89088Cd14064f38E5B2F309cFaB9C864F9a8e6 \
PRICE_FEED=0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E \
UNISWAP_POOL_FEE=500 \
npx hardhat run scripts/sepolia/deploy_dca_pool.ts --network sepolia
```

### fDAI>>fUSDC