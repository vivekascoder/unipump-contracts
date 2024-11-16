# Notes

```

Buyy
x: price of 1 token in WETH
1 token = x WETH
1000 WETH = 1000 / x token


Sell:
1 token = xWETH
1000 token = x*1000WETH
```

# Things to do

- Initialize new pool with the dynamic fee hook
  - [x] Compute the sqrt price thingy for the current price.
  - [x] TEst teh create new pool hook
- [x] Write test
- [x] generalize the unipump contract by using Map<PoolKey, DataForPool>
- [x] Add events and other info.
- [x] Deploy the contract on testnet.
- [x] index price data for the pool.
- [x] pyth oracle support for threshold WETH price
- [x] change the mock token to WETH
- [x] in dynamic fee use reduce when side changes.
- [x] Indexer indexes prices in USDC
