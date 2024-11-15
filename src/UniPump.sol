// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {UD60x18, ud} from "@prb/math/src/UD60x18.sol";
import {UD60x18 as UD, ud, exp, intoUint256, floor, sqrt} from "@prb/math/src/UD60x18.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import "forge-std/Script.sol";
import "./MemeToken.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {BeforeSwapDelta, toBeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";
import "./DynamicFeeHook.sol";
import {LPFeeLibrary} from "v4-core/src/libraries/LPFeeLibrary.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "v4-core/test/utils/LiquidityAmounts.sol";
import "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";

contract UniPump is BaseHook, IEntropyConsumer {
    using PoolIdLibrary for PoolKey;

    // NOTE: ---------------------------------------------------------
    // state variables should typically be unique to a pool
    // a single hook contract should be able to service multiple pools
    // ---------------------------------------------------------------

    mapping(PoolId => uint256 count) public beforeSwapCount;
    mapping(PoolId => uint256 count) public afterSwapCount;

    mapping(PoolId => uint256 count) public beforeAddLiquidityCount;
    mapping(PoolId => uint256 count) public beforeRemoveLiquidityCount;

    // Map<pool, Map<user, points>>
    uint256 public constant DEFAULT_FEE = 10_000; // 1%
    uint256 public constant INITIAL_MINT_AMOUNT = 1093_100_000e18;
    UD public M = ud(100_000e18);

    // last price of the token
    // UD lastPrice = ud(0);
    // UD supply = ud(0);
    // UD locked = ud(0);
    address usdcAddress;
    // address tokenAddress;
    uint256 public constant POST_SALE_LIMIT = 5000e18;
    // bool poolIsLive = false;
    address usdc;
    // bool isToken0USDC = false;
    IPoolManager pm;
    address CREATE2_DEPLOYER;
    DynamicFeeHook feeHook;
    IEntropy entropy;
    address provider;
    UD beta;

    struct PoolSaleState {
        address tokenAddress;
        bool poolIsLive;
        UD lastPrice;
        UD supply;
        UD locked;
        bool isToken0USDC;
    }

    event PriceChange(address tokenAddress, uint256 price, uint256 timestamp);
    event Random(uint256 number);

    mapping(PoolId => PoolSaleState) public poolSaleStates;

    constructor(
        IPoolManager _poolManager,
        address _usdc,
        address _create2Deployer,
        address _feeHook,
        address _entropy,
        address _provider
    ) BaseHook(_poolManager) {
        usdc = _usdc;
        pm = _poolManager;
        CREATE2_DEPLOYER = _create2Deployer;
        feeHook = DynamicFeeHook(_feeHook);
        entropy = IEntropy(_entropy);
        provider = _provider;
    }

    /// required by the IEntropyConsumer interface.
    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }

    function entropyCallback(uint64, address, bytes32 randomNumber) internal override {
        uint256 number = (uint256(randomNumber) % 19) + 1;
        beta = (ud(number * 1e18).div(ud(100e18))).add(ud(1e18));
        emit Random(intoUint256(beta));
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function curve(UD x) public pure returns (UD) {
        UD ex = exp(ud(0.00003606e18).mul(x));
        return ud(0.6015e18).mul(ex);
    }

    // Price of 10M tokens
    function price(PoolKey memory key) public view returns (UD) {
        return curve(cap(key)).div(M);
    }

    // Market cap of the token
    function cap(PoolKey memory key) public view returns (UD) {
        // get pool state
        PoolSaleState storage state = poolSaleStates[key.toId()];
        return state.lastPrice.mul(state.supply);
    }

    function buyTokenFromSale(PoolKey memory key, uint256 _amount) external {
        // get pool state
        PoolSaleState storage state = poolSaleStates[key.toId()];

        UD usdc_amount = ud(_amount);
        // transfer USDC from the user to the contract
        IERC20(usdcAddress).transferFrom(msg.sender, address(this), intoUint256(usdc_amount));
        UD current_price = price(key);
        console.log("current price", intoUint256(current_price));
        UD tokenOut = usdc_amount.div(current_price);

        require(state.supply >= tokenOut, "tokenOut is greater than state.supply");

        state.locked = state.locked.add(usdc_amount);
        state.supply = state.supply.sub(tokenOut);

        state.lastPrice = price(key);

        require(
            IERC20(state.tokenAddress).balanceOf(address(this)) >= intoUint256(tokenOut),
            "Not enough tokens in the contract"
        );

        emit PriceChange(state.tokenAddress, intoUint256(price(key)), block.timestamp);

        // transfer tokenOut
        IERC20(state.tokenAddress).transfer(msg.sender, intoUint256(tokenOut));
    }

    function sellTokenFromSale(PoolKey memory key, uint256 _amount) external {
        // get pool state
        PoolSaleState storage state = poolSaleStates[key.toId()];

        UD token_amount = ud(_amount);
        IERC20(state.tokenAddress).transfer(address(this), _amount);

        UD current_price = price(key);
        console.log("price before", intoUint256(current_price), "token amount", intoUint256(token_amount));
        console.log("locked", intoUint256(state.locked));
        UD usdcOut = current_price.div(token_amount);

        require(state.locked >= usdcOut, "Not enough USDC in the contract");

        console.log("usdcOut", intoUint256(usdcOut));

        state.supply = state.supply.add(token_amount);
        state.locked = state.locked.sub(usdcOut);

        state.lastPrice = price(key);
        console.log("last price", intoUint256(usdcOut));

        emit PriceChange(state.tokenAddress, intoUint256(price(key)), block.timestamp);

        // transfer USDC to the user
        IERC20(usdcAddress).transfer(msg.sender, intoUint256(usdcOut));
    }

    /// @dev floor(sqrt(A / B) * 2 ** 96)
    function computeSqrtPrice(UD priceOf1Token) public pure returns (UD) {
        return floor(sqrt(priceOf1Token).mul(ud(2e18).pow(ud(96e18))));
    }

    /// @dev create new pool, add liquidity.
    function postSaleAddLiquidityAndBurn(PoolKey memory key, address _lpRouter, address _swapRouter) external {
        // get pool state
        PoolSaleState storage state = poolSaleStates[key.toId()];

        // make sure the market cap is high enough
        require(intoUint256(cap(key)) >= POST_SALE_LIMIT, "Market cap is too low");
        state.poolIsLive = true;

        address token0;
        address token1;
        console.log("isToken0USDC", state.isToken0USDC);
        if (state.isToken0USDC) {
            token0 = usdcAddress;
            token1 = state.tokenAddress;
        } else {
            token0 = state.tokenAddress;
            token1 = usdcAddress;
        }

        int24 tickSpacing = 60;
        PoolKey memory poolKey = PoolKey(
            Currency.wrap(token0),
            Currency.wrap(token1),
            LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing,
            IHooks(address(feeHook))
        );

        console.log("usdc", usdc);
        console.log("meme", state.tokenAddress);

        UD lprice = price(key);
        console.log("lprice", intoUint256(lprice));
        console.log("halfLocked", intoUint256(state.locked) / 2);
        uint256 currentSqrtPrice = intoUint256(computeSqrtPrice(lprice)) / 1e18;
        console.log("currentSqrtPrice", currentSqrtPrice);
        poolManager.initialize(poolKey, uint160(currentSqrtPrice));

        // // add liquidity
        PoolModifyLiquidityTest router = PoolModifyLiquidityTest(_lpRouter);

        uint256 halfLocked = (intoUint256(state.locked) / 2);
        // require(halfLocked <= (type(int256).max), "SafeCastOverflow: halfLocked exceeds int256 max");

        // console.log("halfLocked", halfLocked);
        MemeToken meme = MemeToken(token1);
        MemeToken usdc = MemeToken(token0);

        meme.mint(address(this), 10_000_000_000e18);

        usdc.approve(address(_lpRouter), type(uint256).max);
        meme.approve(address(_lpRouter), type(uint256).max);
        usdc.approve(address(_swapRouter), type(uint256).max);
        meme.approve(address(_swapRouter), type(uint256).max);
        console.log("balance of meme", meme.balanceOf(address(this)));

        uint128 liq = LiquidityAmounts.getLiquidityForAmount0(
            TickMath.getSqrtPriceAtTick(TickMath.minUsableTick(tickSpacing)),
            TickMath.getSqrtPriceAtTick(TickMath.maxUsableTick(tickSpacing)),
            halfLocked
        );
        console.log("liq", liq);

        router.modifyLiquidity(
            poolKey,
            IPoolManager.ModifyLiquidityParams(
                TickMath.minUsableTick(tickSpacing), TickMath.maxUsableTick(tickSpacing), int256(int128(liq)), 0
            ),
            new bytes(0)
        );
    }

    // /// @notice Add liquidity through the hook
    // /// @dev Not production-ready, only serves an example of hook-owned liquidity
    // function addLiquidity(PoolKey calldata key, uint256 amount0, uint256 amount1) external {
    //     poolManager.unlock(
    //         abi.encodeCall(this.handleAddLiquidity, (key.currency0, key.currency1, amount0, amount1, msg.sender))
    //     );
    // }

    // /// @dev Handle liquidity addition by taking tokens from the sender and claiming ERC6909 to the hook address
    // function handleAddLiquidity(
    //     Currency currency0,
    //     Currency currency1,
    //     uint256 amount0,
    //     uint256 amount1,
    //     address sender
    // ) external selfOnly returns (bytes memory) {
    //     currency0.settle(poolManager, sender, amount0, false);
    //     currency0.take(poolManager, address(this), amount0, true);

    //     currency1.settle(poolManager, sender, amount1, false);
    //     currency1.take(poolManager, address(this), amount1, true);

    //     return abi.encode(amount0, amount1);
    // }

    function beforeInitialize(address, PoolKey calldata key, uint160) external override returns (bytes4) {
        // get pool state
        PoolSaleState storage state = poolSaleStates[key.toId()];

        // if curency0 is USDC then we know that token1 is the token.
        console.log("Currency 0", Currency.unwrap(key.currency0), "usdc", usdc);
        if (Currency.unwrap(key.currency0) == usdc) {
            usdcAddress = Currency.unwrap(key.currency0);
            state.tokenAddress = Currency.unwrap(key.currency1);
            state.isToken0USDC = true;
        } else {
            usdcAddress = Currency.unwrap(key.currency1);
            state.tokenAddress = Currency.unwrap(key.currency0);
            state.isToken0USDC = false;
        }

        MemeToken meme = MemeToken(state.tokenAddress);
        console.log("MemeToken owner", address(meme));
        require(meme.owner() == address(this), "MemeToken is not owned by this contract");

        // mint X amount of tokens.
        meme.mint(address(this), INITIAL_MINT_AMOUNT);
        state.supply = ud(INITIAL_MINT_AMOUNT);

        // make sure the hook owns the current address.
        return BaseHook.beforeInitialize.selector;
    }

    // -----------------------------------------------
    // NOTE: see IHooks.sol for function documentation
    // -----------------------------------------------

    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        // // can only be swapped once the sale is finished and liq is added
        // // require(poolIsLive, "Pool is not live yet");
        // if (params.amountSpecified < 0) {
        //     // take the input token so that v3-swap is skipped...
        //     Currency input = params.zeroForOne ? key.currency0 : key.currency1;
        //     uint256 amountTaken = uint256(-params.amountSpecified);
        //     poolManager.mint(address(this), input.toId(), amountTaken);

        //     // to NoOp the exact input, we return the amount that's taken by the hook
        //     return (BaseHook.beforeSwap.selector, toBeforeSwapDelta(amountTaken.toInt128(), 0), 0);
        // } else {
        //     return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO, 0);
        // }
        require(false, "Not implemented");
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    // function afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
    //     external
    //     override
    //     returns (bytes4, int128)
    // {
    //     afterSwapCount[key.toId()]++;
    //     return (BaseHook.afterSwap.selector, 0);
    // }

    function beforeAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata
    ) external override returns (bytes4) {
        // get pool state
        PoolSaleState storage state = poolSaleStates[key.toId()];
        require(state.poolIsLive, "Pool is not live yet");
        return BaseHook.beforeAddLiquidity.selector;
    }

    function beforeRemoveLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        // get pool state
        PoolSaleState storage state = poolSaleStates[key.toId()];
        require(state.poolIsLive, "Pool is not live yet");
        return BaseHook.beforeRemoveLiquidity.selector;
    }
}
