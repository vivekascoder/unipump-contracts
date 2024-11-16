# v4-template

### **A template for writing Uniswap v4 Hooks 🦄**

[`Use this Template`](https://github.com/uniswapfoundation/v4-template/generate)

1. The example hook [Counter.sol](src/Counter.sol) demonstrates the `beforeSwap()` and `afterSwap()` hooks
2. The test template [Counter.t.sol](test/Counter.t.sol) preconfigures the v4 pool manager, test tokens, and test liquidity.

<details>
<summary>Updating to v4-template:latest</summary>

This template is actively maintained -- you can update the v4 dependencies, scripts, and helpers:

```bash
git remote add template https://github.com/uniswapfoundation/v4-template
git fetch template
git merge template/main <BRANCH> --allow-unrelated-histories
```

</details>

---

### Check Forge Installation

_Ensure that you have correctly installed Foundry (Forge) and that it's up to date. You can update Foundry by running:_

```
foundryup
```

## Set up

_requires [foundry](https://book.getfoundry.sh)_

```
forge install
forge test
```

### Local Development (Anvil)

Other than writing unit tests (recommended!), you can only deploy & test hooks on [anvil](https://book.getfoundry.sh/anvil/)

```bash
# start anvil, a local EVM chain
anvil

# in a new terminal
forge script script/Anvil.s.sol \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast
```

See [script/](script/) for hook deployment, pool creation, liquidity provision, and swapping.

---

<details>
<summary><h2>Troubleshooting</h2></summary>

### _Permission Denied_

When installing dependencies with `forge install`, Github may throw a `Permission Denied` error

Typically caused by missing Github SSH keys, and can be resolved by following the steps [here](https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh)

Or [adding the keys to your ssh-agent](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#adding-your-ssh-key-to-the-ssh-agent), if you have already uploaded SSH keys

### Hook deployment failures

Hook deployment failures are caused by incorrect flags or incorrect salt mining

1. Verify the flags are in agreement:
   - `getHookCalls()` returns the correct flags
   - `flags` provided to `HookMiner.find(...)`
2. Verify salt mining is correct:
   - In **forge test**: the _deployer_ for: `new Hook{salt: salt}(...)` and `HookMiner.find(deployer, ...)` are the same. This will be `address(this)`. If using `vm.prank`, the deployer will be the pranking address
   - In **forge script**: the deployer must be the CREATE2 Proxy: `0x4e59b44847b379578588920cA78FbF26c0B4956C`
     - If anvil does not have the CREATE2 deployer, your foundry may be out of date. You can update it with `foundryup`

</details>

---

Additional resources:

[Uniswap v4 docs](https://docs.uniswap.org/contracts/v4/overview)

[v4-periphery](https://github.com/uniswap/v4-periphery) contains advanced hook implementations that serve as a great reference

[v4-core](https://github.com/uniswap/v4-core)

[v4-by-example](https://v4-by-example.org)

## notes

- dynamic fee hook

```solidity
poolKey = PoolKey(
    currency0,
    currency1,
    LPFeeLibrary.DYNAMIC_FEE_FLAG, // signal that the pool has a dynamic fee
    60,
    IHooks(hook)
);
manager.initialize(poolKey, startingPrice, hookData);
```

```bash

# solidity test script
forge script script/UniPump.s.sol \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast --via-ir -vvvvv
```

```bash
# deployment script
forge script script/DeployUniPumpCreator.s.sol\
    --rpc-url $RPC \
    --private-key $PK \
    --broadcast --via-ir -vvvvv
```

## Info on function calls

Buy token

```solidity
    function buyTokenFromSale(address _addr, uint256 _amount) external
```

```solidity
    function sellTokenFromSale(address _addr, uint256 _amount) external
```

```solidity
struct PoolKey {
    /// @notice The lower currency of the pool, sorted numerically
    Currency currency0;
    /// @notice The higher currency of the pool, sorted numerically
    Currency currency1;
    /// @notice The pool LP fee, capped at 1_000_000. If the highest bit is 1, the pool has a dynamic fee and must be exactly equal to 0x800000
    uint24 fee;
    /// @notice Ticks that involve positions must be a multiple of tick spacing
    int24 tickSpacing;
    /// @notice The hooks of the pool
    IHooks hooks;
}
```

To create sale for a meme token call this from `UniPumpCreator`

```
    function createTokenSale(
        string memory _name,
        string memory _symbol,
        string memory _twitter,
        string memory _discord,
        string memory _bio,
        string memory _imageUri
    ) public returns (address)
```

To get market cap

```solidity
    function cap(address _addr) public view returns (UD)
```

To get the price of the token

```solidity
    function price(address _addr) public view returns (UD)
```

## Deployed Addresses

```
== Logs ==
  UniPumpCreator:  0xADA0Ff7C8F108E311Ca7c82845A1b8ef26E90e11
  UniPump:  0xe7f06CC969f37958BCAf6AF7C9f93b251338EA80
  FeeHook:  0xb65b299f330Bbf4C0D4115737388Dd3b61cc50c0
  weth:  0x4267D742e4fD1C03805083b087DeB575203e9b19
```
