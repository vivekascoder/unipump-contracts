// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";

/// @notice A time-decaying dynamically fee, updated manually with external PoolManager.updateDynamicSwapFee() calls
contract DynamicFeeHook is BaseHook {
    uint256 public immutable startTimestamp;
    uint128 public constant START_FEE = 100_000; // represents 1%
    uint128 public constant BUY_FEE = 50_000; // minimum fee of 0.05%
    uint128 public constant decayRate = 1; // 0.00001% per second
    address weth;

    constructor(IPoolManager _poolManager, address _weth) BaseHook(_poolManager) {
        startTimestamp = block.timestamp;
        weth = _weth;
    }

    /// @dev Deteremines a Pool's swap fee
    function setFee(PoolKey calldata key, uint256 _fee) public {
        poolManager.updateDynamicLPFee(key, uint24(_fee));
    }

    function afterInitialize(address, PoolKey calldata key, uint160, int24) external override returns (bytes4) {
        // after pool is initialized, set the initial fee
        setFee(key, START_FEE);
        return BaseHook.afterInitialize.selector;
    }

    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata swapParams, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        if (Currency.unwrap(key.currency0) == weth && swapParams.zeroForOne) {
            // if the pool involves WETH, set the fee to the minimum
            setFee(key, BUY_FEE);
            return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        } else if (Currency.unwrap(key.currency1) == weth && !swapParams.zeroForOne) {
            // if the pool involves WETH, set the fee to the minimum
            setFee(key, BUY_FEE);
            return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        } else {
            setFee(key, START_FEE);
        }

        // before every swap, update the fee
        setFee(key, BUY_FEE);
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
        external
        override
        returns (bytes4, int128)
    {
        // after every swap, update the fee
        setFee(key, START_FEE);
        return (BaseHook.afterSwap.selector, 0);
    }

    /// @dev this example hook contract does not implement any hooks
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }
}
