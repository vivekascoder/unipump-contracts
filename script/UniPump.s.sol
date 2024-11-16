// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {PoolDonateTest} from "v4-core/src/test/PoolDonateTest.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Constants} from "v4-core/src/../test/utils/Constants.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
// import {Counter} from "../src/Counter.sol";
import {UniPump} from "../src/UniPump.sol";
import {UniPumpCreator} from "../src/UniPumpCreator.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {PositionManager} from "v4-periphery/src/PositionManager.sol";
import {EasyPosm} from "../test/utils/EasyPosm.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {DeployPermit2} from "../test/utils/forks/DeployPermit2.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPositionDescriptor} from "v4-periphery/src/interfaces/IPositionDescriptor.sol";
import {UD60x18 as UD, ud, exp, intoUint256} from "@prb/math/src/UD60x18.sol";
import {MemeToken} from "../src/MemeToken.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";
import "v4-core/test/utils/LiquidityAmounts.sol";
import "../src/DynamicFeeHook.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "@pythnetwork/pyth-sdk-solidity/MockPyth.sol";

/// @notice Forge script for deploying v4 & hooks to **anvil**
/// @dev This script only works on an anvil RPC because v4 exceeds bytecode limits
contract UniPumpScript is Script, DeployPermit2 {
    using EasyPosm for IPositionManager;
    using stdStorage for StdStorage;

    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    MemeToken token0;
    MemeToken token1;
    MemeToken weth;
    MemeToken meme;
    UniPump hook;
    address entropy = 0x41c9e39574F40Ad34c79f1C99B66A45eFB830d4c;
    address provider = 0x6CC14824Ea2918f5De5C2f75A9Da968ad4BD6344;
    address priceFeedContract = 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729;
    bytes32 priceFeedWethId = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;

    function setUp() public {}

    function run() public {
        vm.broadcast();
        IPoolManager manager = deployPoolManager();

        // hook contracts must have specific flags encoded in the address
        uint160 permissions = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
                | Hooks.BEFORE_INITIALIZE_FLAG
        );

        vm.startBroadcast();
        (token0, token1) = deployTokens();
        weth = token0;
        meme = token1;
        vm.stopBroadcast();

        uint160 feeHookPermissions =
            uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_INITIALIZE_FLAG);
        (address feeHookAddress, bytes32 feeeHookSalt) = HookMiner.find(
            CREATE2_DEPLOYER,
            feeHookPermissions,
            type(DynamicFeeHook).creationCode,
            abi.encode(address(manager), address(weth))
        );

        vm.broadcast();
        DynamicFeeHook feeHook = new DynamicFeeHook{salt: feeeHookSalt}(manager, address(weth));
        require(address(feeHook) == feeHookAddress, "UniPump: fee hook address mismatch");

        // Mine a salt that will produce a hook address with the correct permissions
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            permissions,
            type(UniPump).creationCode,
            abi.encode(
                address(manager),
                address(weth),
                CREATE2_DEPLOYER,
                address(feeHook),
                entropy,
                provider,
                priceFeedContract,
                priceFeedWethId
            )
        );

        // ----------------------------- //
        // Deploy the hook using CREATE2 //
        // ----------------------------- //

        vm.broadcast();
        UniPump unipump = new UniPump{salt: salt}(
            manager,
            address(weth),
            CREATE2_DEPLOYER,
            address(feeHook),
            entropy,
            provider,
            priceFeedContract,
            priceFeedWethId
        );

        hook = unipump;

        // top up
        vm.broadcast();
        payable(address(unipump)).transfer(1 ether);

        require(address(unipump) == hookAddress, "CounterScript: hook address mismatch");

        // Additional helpers for interacting with the pool
        vm.startBroadcast();
        IPositionManager posm = deployPosm(manager);
        (PoolModifyLiquidityTest lpRouter, PoolSwapTest swapRouter,) = deployRouters(manager);
        vm.stopBroadcast();

        // test the lifecycle (create pool, add liquidity, swap)
        vm.startBroadcast();
        testLifecycle(manager, address(unipump), posm, lpRouter, swapRouter, feeHookAddress);
        vm.stopBroadcast();
    }

    // -----------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------
    function deployPoolManager() internal returns (IPoolManager) {
        return IPoolManager(address(new PoolManager()));
    }

    function deployRouters(IPoolManager manager)
        internal
        returns (PoolModifyLiquidityTest lpRouter, PoolSwapTest swapRouter, PoolDonateTest donateRouter)
    {
        lpRouter = new PoolModifyLiquidityTest(manager);
        swapRouter = new PoolSwapTest(manager);
        donateRouter = new PoolDonateTest(manager);
    }

    function deployPosm(IPoolManager poolManager) public returns (IPositionManager) {
        anvilPermit2();
        return IPositionManager(new PositionManager(poolManager, permit2, 300_000, IPositionDescriptor(address(0))));
    }

    function approvePosmCurrency(IPositionManager posm, Currency currency) internal {
        // Because POSM uses permit2, we must execute 2 permits/approvals.
        // 1. First, the caller must approve permit2 on the token.
        IERC20(Currency.unwrap(currency)).approve(address(permit2), type(uint256).max);
        // 2. Then, the caller must approve POSM as a spender of permit2
        permit2.approve(Currency.unwrap(currency), address(posm), type(uint160).max, type(uint48).max);
    }

    function deployTokens() internal returns (MemeToken token0, MemeToken token1) {
        MemeToken tokenA = new MemeToken("MockA", "A", 18);
        MemeToken tokenB = new MemeToken("MockB", "B", 18);
        if (uint160(address(tokenA)) < uint160(address(tokenB))) {
            token0 = tokenA;
            token1 = tokenB;
        } else {
            token0 = tokenB;
            token1 = tokenA;
        }
    }

    function testLifecycle(
        IPoolManager manager,
        address _hook,
        IPositionManager posm,
        PoolModifyLiquidityTest lpRouter,
        PoolSwapTest swapRouter,
        address _feeHook
    ) internal {
        token0.mint(msg.sender, 100_000 ether);
        weth = token0;
        MemeToken meme = token0;

        // deploy MockPyth

        // token1.mint(msg.sender, 100_000 ether);

        // bytes memory ZERO_BYTES = new bytes(0);

        // // initialize the pool
        // int24 tickSpacing = 60;
        // MemeToken meme = MemeToken(token1);
        // meme.transferOwnership(address(hook));

        // PoolKey memory poolKey =
        //     PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3000, tickSpacing, IHooks(hook));
        // manager.initialize(poolKey, Constants.SQRT_PRICE_1_1);

        // // approve the tokens to the routers
        // // token0.approve(address(lpRouter), type(uint256).max);
        // // token1.approve(address(lpRouter), type(uint256).max);
        // // token0.approve(address(swapRouter), type(uint256).max);
        // // token1.approve(address(swapRouter), type(uint256).max);

        // // approvePosmCurrency(posm, Currency.wrap(address(token0)));
        // // approvePosmCurrency(posm, Currency.wrap(address(token1)));

        // // hook related tests.

        // UD price = hook.computeSqrtPrice(ud(0.78e18));
        // console.log("Sqrt price: ", intoUint256(price));

        UniPumpCreator creator =
            new UniPumpCreator(address(manager), address(token0), CREATE2_DEPLOYER, _hook, _feeHook);

        address memeTokenAddress =
            creator.createTokenSale("Meme", "MEME", "twitter", "discord", "bio", "http://placekitteam.com/100/100");

        address token0;
        address token1;
        bool iswethToken0;
        if (memeTokenAddress > address(weth)) {
            token0 = address(weth);
            token1 = memeTokenAddress;
            iswethToken0 = true;
        } else {
            token0 = memeTokenAddress;
            token1 = address(weth);
            iswethToken0 = false;
        }

        PoolKey memory poolKey =
            PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3000, 60, IHooks(hook));
        // manager.initialize(poolKey, Constants.SQRT_PRICE_1_1);

        // current price.
        uint256 currentPrice = intoUint256(hook.price(memeTokenAddress));
        console.log("Current price: ", currentPrice);

        // // buy tokens off of sale.

        uint256 liq = LiquidityAmounts.getLiquidityForAmount0(
            TickMath.getSqrtPriceAtTick(TickMath.minUsableTick(60)),
            TickMath.getSqrtPriceAtTick(TickMath.maxUsableTick(60)),
            10e18
        );

        console.log("Liq: ", liq);

        meme.approve(address(hook), type(uint256).max);
        hook.buyTokenFromSale(memeTokenAddress, 500e18);

        // // hook.buyTokenFromSale(100e18);

        // token1.approve(address(hook), type(uint256).max);

        console.log("Price: ", intoUint256(hook.price(memeTokenAddress)));

        IERC20(memeTokenAddress).approve(address(hook), 1e18);

        hook.sellTokenFromSale(memeTokenAddress, 1e18);

        // console.log("Price: ", intoUint256(hook.price()));

        // console.log("Cap: ", intoUint256(hook.cap()));

        // // add full range liquidity to the pool
        // // lpRouter.modifyLiquidity(
        // //     poolKey,
        // //     IPoolManager.ModifyLiquidityParams(
        // //         TickMath.minUsableTick(tickSpacing), TickMath.maxUsableTick(tickSpacing), 100 ether, 0
        // //     ),
        // //     ZERO_BYTES
        // // );

        // // stdstore.target(address(hook)).sig("a(address)").checked_write(0.28e18);
        // console.log("Cap: ", intoUint256(hook.cap()));

        bytes[] memory params = new bytes[](0);
        uint256 oracleFee = IPyth(priceFeedContract).getUpdateFee(params);

        hook.postSaleAddLiquidityAndBurn{value: oracleFee}(
            memeTokenAddress, address(lpRouter), address(swapRouter), params
        );
        // // posm.mint(
        // //     poolKey,
        // //     TickMath.minUsableTick(tickSpacing),
        // //     TickMath.maxUsableTick(tickSpacing),
        // //     100e18,
        // //     10_000e18,
        // //     10_000e18,
        // //     msg.sender,
        // //     block.timestamp + 300,
        // //     ZERO_BYTES
        // // );

        // // // swap some tokens
        // // bool zeroForOne = true;
        // // int256 amountSpecified = 1 ether;
        // // IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
        // //     zeroForOne: zeroForOne,
        // //     amountSpecified: amountSpecified,
        // //     sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1 // unlimited impact
        // // });
        // // PoolSwapTest.TestSettings memory testSettings =
        // //     PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});

        // // swapRouter.swap(poolKey, params, testSettings, ZERO_BYTES);
    }
}
