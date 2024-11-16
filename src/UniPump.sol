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
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

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
    uint24 public constant DEFAULT_FEE = 10_000; // 1%
    uint256 public constant INITIAL_MINT_AMOUNT = 1_000_000_000e18;
    UD public M = ud(1_000_000e18);

    address wethAddress;
    uint256 public constant POST_SALE_LIMIT = 6.9e18;
    address weth;
    IPoolManager pm;
    address CREATE2_DEPLOYER;
    DynamicFeeHook feeHook;
    IEntropy entropy;
    address provider;
    IPyth pyth;
    bytes32 priceFeedWethId;

    struct PoolSaleState {
        address tokenAddress;
        bool poolIsLive;
        UD lastPrice;
        UD supply;
        UD locked;
        bool isToken0weth;
        UD beta;
    }

    UD tempBeta = ud(1);
    PoolId tempPoolId;

    event PriceChange(address tokenAddress, uint256 price, uint256 timestamp, uint256 oraclePrice);
    event Random(uint256 number);

    mapping(PoolId => PoolSaleState) public poolSaleStates;

    receive() external payable {}

    constructor(
        IPoolManager _poolManager,
        address _weth,
        address _create2Deployer,
        address _feeHook,
        address _entropy,
        address _provider,
        address _pyth,
        bytes32 _priceFeedWethId
    ) BaseHook(_poolManager) {
        weth = _weth;
        pm = _poolManager;
        CREATE2_DEPLOYER = _create2Deployer;
        feeHook = DynamicFeeHook(_feeHook);
        entropy = IEntropy(_entropy);
        provider = _provider;
        pyth = IPyth(_pyth);
        priceFeedWethId = _priceFeedWethId;
    }

    /// required by the IEntropyConsumer interface.
    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }

    function entropyCallback(uint64, address, bytes32 randomNumber) internal override {
        uint256 number = (uint256(randomNumber) % 19) + 1;
        tempBeta = (ud(number * 1e18).div(ud(100e18))).add(ud(1e18));
        PoolSaleState storage state = poolSaleStates[tempPoolId];
        state.beta = tempBeta;
        emit Random(intoUint256(tempBeta));
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

    function getPoolKey(address _addr) public view returns (PoolKey memory) {
        address token0;
        address token1;

        if (_addr > weth) {
            token0 = weth;
            token1 = _addr;
        } else {
            token0 = _addr;
            token1 = weth;
        }

        PoolKey memory poolKey = PoolKey(
            Currency.wrap(address(token0)), Currency.wrap(address(token1)), DEFAULT_FEE, 60, IHooks(address(this))
        );
        return poolKey;
    }

    function getPoolState(address _addr) public view returns (PoolSaleState memory) {
        PoolId poolId = getPoolKey(_addr).toId();
        return poolSaleStates[poolId];
    }

    function curve(UD x) public pure returns (UD) {
        UD ex = exp(ud(0.00003606e18).mul(x));
        return ud(0.6015e18).mul(ex);
    }

    // Price of 10M tokens
    function price(address _addr) public view returns (UD) {
        return curve(cap(_addr)).div(M);
    }

    // Market cap of the token
    function cap(address _addr) public view returns (UD) {
        PoolKey memory key = getPoolKey(_addr);
        // get pool state
        PoolSaleState storage state = poolSaleStates[key.toId()];
        return state.lastPrice.mul(state.supply);
    }

    function buyTokenFromSale(address _addr, uint256 _amount) external {
        // get pool state
        PoolKey memory key = getPoolKey(_addr);
        PoolSaleState storage state = poolSaleStates[key.toId()];

        require(!state.poolIsLive, "Pool is live, plz trade on uni pool now");

        UD weth_amount = ud(_amount);
        // transfer weth from the user to the contract
        IERC20(wethAddress).transferFrom(msg.sender, address(this), intoUint256(weth_amount));
        UD current_price = price(_addr);
        console.log("current price", intoUint256(current_price));
        UD tokenOut = weth_amount.div(current_price);

        // MemeToken meme = MemeToken(state.tokenAddress);

        // require(meme.balanceOf(address(this)) >= intoUint256(tokenOut), "tokenOut is greater than state.supply");

        state.locked = state.locked.add(weth_amount);
        state.supply = state.supply.add(tokenOut);

        state.lastPrice = price(_addr);

        require(
            IERC20(state.tokenAddress).balanceOf(address(this)) >= intoUint256(tokenOut),
            "Not enough tokens in the contract"
        );

        uint256 wethPrice = getWethPrice();
        emit PriceChange(state.tokenAddress, intoUint256(state.lastPrice), block.timestamp, wethPrice);

        // transfer tokenOut
        IERC20(state.tokenAddress).transfer(msg.sender, intoUint256(tokenOut));
    }

    function sellTokenFromSale(address _addr, uint256 _amount) external {
        PoolKey memory key = getPoolKey(_addr);
        // get pool state
        PoolSaleState storage state = poolSaleStates[key.toId()];

        require(!state.poolIsLive, "Pool is live, plz trade on uni pool now");

        UD token_amount = ud(_amount);
        IERC20(state.tokenAddress).transferFrom(msg.sender, address(this), _amount);

        UD current_price = price(_addr);
        state.supply = state.supply.sub(token_amount);
        console.log("price before", intoUint256(current_price), "token amount", intoUint256(token_amount));
        console.log("locked", intoUint256(state.locked));
        UD wethOut = token_amount.mul(current_price);
        console.log("wethOut", intoUint256(wethOut));

        require(state.locked >= wethOut, "Not enough weth in the contract");

        console.log("wethOut", intoUint256(wethOut));

        state.locked = state.locked.sub(wethOut);

        state.lastPrice = price(_addr);
        console.log("last price", intoUint256(wethOut));

        uint256 wethPrice = getWethPrice();
        emit PriceChange(state.tokenAddress, intoUint256(price(_addr)), block.timestamp, wethPrice);

        // transfer weth to the user
        IERC20(wethAddress).transfer(msg.sender, intoUint256(wethOut));
    }

    /// @dev floor(sqrt(A / B) * 2 ** 96)
    function computeSqrtPrice(UD priceOf1Token) public pure returns (UD) {
        return floor(sqrt(priceOf1Token).mul(ud(2e18).pow(ud(96e18))));
    }

    function getWethPrice() public view returns (uint256) {
        PythStructs.Price memory wethPrice = pyth.getPriceUnsafe(priceFeedWethId);
        uint256 oraclePrice = uint256(int256(wethPrice.price)) * 10 ** 10;
        return oraclePrice;
    }

    /// @dev create new pool, add liquidity.
    function postSaleAddLiquidityAndBurn(
        address _addr,
        address _lpRouter,
        address _swapRouter,
        bytes[] calldata priceUpdate
    ) external payable {
        PoolKey memory key = getPoolKey(_addr);
        // get pool state
        PoolSaleState storage state = poolSaleStates[key.toId()];

        // Fetcht the WETH price from pyth oracle.
        // uint256 fee = pyth.getUpdateFee(priceUpdate);
        // pyth.updatePriceFeeds{value: fee}(priceUpdate);

        // uint256 wethPrice = getWethPrice();

        // make sure the market cap is high enough
        // require(intoUint256(cap(_addr)) >= POST_SALE_LIMIT, "Market cap is too low");
        // require(intoUint256(cap(_addr).mul(ud(wethPrice))) >= 20000e18, "Market cap is too low");
        require(intoUint256(state.supply) >= 800_000_000e18, "800M isn't reached yet, Supply is too low");
        state.poolIsLive = true;

        address token0;
        address token1;
        console.log("isToken0weth", state.isToken0weth);
        if (state.isToken0weth) {
            token0 = wethAddress;
            token1 = state.tokenAddress;
        } else {
            token0 = state.tokenAddress;
            token1 = wethAddress;
        }

        int24 tickSpacing = 60;
        PoolKey memory poolKey = PoolKey(
            Currency.wrap(token0),
            Currency.wrap(token1),
            LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing,
            IHooks(address(feeHook))
        );

        console.log("weth", weth);
        console.log("meme", state.tokenAddress);

        UD lprice = price(_addr);
        console.log("lprice", intoUint256(lprice));
        console.log("halfLocked", intoUint256(state.locked) / 2);
        uint256 currentSqrtPrice = intoUint256(computeSqrtPrice(lprice)) / 1e18;
        console.log("currentSqrtPrice", currentSqrtPrice);

        // init the pool with dynamic fee.
        poolManager.initialize(poolKey, uint160(currentSqrtPrice));

        // // add liquidity
        PoolModifyLiquidityTest router = PoolModifyLiquidityTest(_lpRouter);

        // 5 % goes to our address
        uint256 liquidityToAdd = intoUint256(state.locked.mul(ud(0.95e18)));

        MemeToken meme = MemeToken(token1);
        MemeToken weth = MemeToken(token0);

        // meme.mint(address(this), 10_000_000_000e18);

        weth.approve(address(_lpRouter), type(uint256).max);
        meme.approve(address(_lpRouter), type(uint256).max);
        weth.approve(address(_swapRouter), type(uint256).max);
        meme.approve(address(_swapRouter), type(uint256).max);
        console.log("balance of meme", meme.balanceOf(address(this)));

        uint128 liq;

        console.log("Liquidity to add: ", liquidityToAdd);
        console.log("min: ", TickMath.getSqrtPriceAtTick(TickMath.minUsableTick(tickSpacing)));
        console.log("max: ", TickMath.getSqrtPriceAtTick(TickMath.maxUsableTick(tickSpacing)));
        int24 MIN_TICK = -887272;
        int24 MAX_TICK = 887272;

        if (state.isToken0weth) {
            liq = LiquidityAmounts.getLiquidityForAmounts(
                uint160(currentSqrtPrice),
                TickMath.getSqrtPriceAtTick(MIN_TICK),
                TickMath.getSqrtPriceAtTick(MAX_TICK),
                liquidityToAdd,
                meme.balanceOf(address(this))
            );
        } else {
            liq = LiquidityAmounts.getLiquidityForAmounts(
                uint160(currentSqrtPrice),
                TickMath.getSqrtPriceAtTick(MIN_TICK),
                TickMath.getSqrtPriceAtTick(MAX_TICK),
                liquidityToAdd,
                meme.balanceOf(address(this))
            );
        }
        console.log("liq", liq);

        router.modifyLiquidity(
            poolKey,
            IPoolManager.ModifyLiquidityParams(
                TickMath.minUsableTick(tickSpacing), TickMath.maxUsableTick(tickSpacing), int256(int128(liq)), 0
            ),
            new bytes(0)
        );

        console.log("weth balance after adding liq: ", IERC20(weth).balanceOf(address(this)));

        // // new expermiment using modifyliquidities
        // bytes memory actions = abi.encodePacked(Actions.MINT_POSITION, Actions.SETTLE_PAIR);
        // uint256 deadline = block.timestamp + 60;
        // bytes[] memory params = new bytes[](2);
        // params[0] = abi.encode(
        //     poolKey,
        //     TickMath.minUsableTick(tickSpacing),
        //     TickMath.maxUsableTick(tickSpacing),
        //     uint256(liq),
        //     uint128(halfLocked),
        //     uint128(meme.balanceOf(address(this))),
        //     address(this),
        //     new bytes(0)
        // );
        // params[1] = abi.encode(Currency.wrap(token0), Currency.wrap(token1));

        // IPositionManager positionManager = IPositionManager(_posm);
        // positionManager.modifyLiquidities(abi.encode(actions, params), deadline);
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
        state.poolIsLive = false;
        state.beta = ud(1);
        state.tokenAddress = Currency.unwrap(key.currency1);

        uint256 wethPrice = getWethPrice();
        console.log("Weth price", wethPrice);
        emit PriceChange(state.tokenAddress, intoUint256(price(state.tokenAddress)), block.timestamp, wethPrice);

        // if curency0 is weth then we know that token1 is the token.
        console.log("Currency 0", Currency.unwrap(key.currency0), "weth", weth);
        if (Currency.unwrap(key.currency0) == weth) {
            wethAddress = Currency.unwrap(key.currency0);
            state.tokenAddress = Currency.unwrap(key.currency1);
            state.isToken0weth = true;
        } else {
            wethAddress = Currency.unwrap(key.currency1);
            state.tokenAddress = Currency.unwrap(key.currency0);
            state.isToken0weth = false;
        }

        MemeToken meme = MemeToken(state.tokenAddress);
        console.log("MemeToken owner", address(meme));
        require(meme.owner() == address(this), "MemeToken is not owned by this contract");

        // mint X amount of tokens.
        meme.mint(address(this), INITIAL_MINT_AMOUNT);
        // state.supply = ud(INITIAL_MINT_AMOUNT);

        // // request random number
        uint128 requestFee = entropy.getFee(provider);
        if (address(this).balance < requestFee) revert("beforeInit: not enough fee");

        tempPoolId = key.toId();

        uint64 _sequenceNumber = entropy.requestWithCallback{value: requestFee}(
            provider, bytes32(0x6bd75275b9fc0a777fb1fec48fcdb3f0aa2d90cd134519dcb699fe31e0b953e5)
        );

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
