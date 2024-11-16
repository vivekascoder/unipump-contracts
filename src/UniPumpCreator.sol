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
import "./UniPump.sol";
import {Constants} from "v4-core/src/../test/utils/Constants.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";

contract UniPumpCreator {
    using PoolIdLibrary for PoolKey;

    uint24 public constant DEFAULT_FEE = 10_000; // 1%

    event TokenSaleCreated(
        address token,
        bool iswethToken0,
        string name,
        string symbol,
        string twitter,
        string discord,
        string bio,
        string imageUri,
        address createdBy
    );

    IPoolManager poolManager;
    address CREATE2_DEPLOYER;
    address unipump;
    address weth;
    address feeHook;

    constructor(address _poolManager, address _weth, address _create2Deployer, address _unipump, address _feeHook) {
        weth = _weth;
        poolManager = IPoolManager(_poolManager);
        CREATE2_DEPLOYER = _create2Deployer;
        unipump = _unipump;
        feeHook = _feeHook;
    }

    function createTokenSale(
        string memory _name,
        string memory _symbol,
        string memory _twitter,
        string memory _discord,
        string memory _bio,
        string memory _imageUri
    ) public returns (address) {
        // deploy fee hook contract
        // uint160 feeHookPermissions =
        //     uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_INITIALIZE_FLAG);
        // (address feeHookAddress, bytes32 feeeHookSalt) = HookMiner.find(
        //     CREATE2_DEPLOYER, feeHookPermissions, type(DynamicFeeHook).creationCode, abi.encode(address(poolManager))
        // );

        // DynamicFeeHook feeHook = new DynamicFeeHook{salt: feeeHookSalt}(poolManager);
        // require(address(feeHook) == feeHookAddress, "UniPumpCreator: fee hook address mismatch");

        // // deploy unipump hook contract
        // uint160 permissions = uint160(
        //     Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
        //         | Hooks.BEFORE_INITIALIZE_FLAG
        // );

        // (address hookAddress, bytes32 salt) = HookMiner.find(
        //     CREATE2_DEPLOYER,
        //     permissions,
        //     type(UniPump).creationCode,
        //     abi.encode(address(poolManager), address(weth), CREATE2_DEPLOYER, address(feeHook))
        // );

        // unipump = address(new UniPump{salt: salt}(poolManager, weth, CREATE2_DEPLOYER, feeHookAddress));
        // require(address(unipump) == hookAddress, "UnipumpCreator: unipump hook address mismatch");

        // deploy meme coin and give ownership to unipump
        MemeToken memeToken = new MemeToken(_name, _symbol, 1);
        memeToken.transferOwnership(address(unipump));

        // compute token0, token1, and iswethToken0
        address token0;
        address token1;
        bool iswethToken0;
        if (address(memeToken) > address(weth)) {
            token0 = address(weth);
            token1 = address(memeToken);
            iswethToken0 = true;
        } else {
            token0 = address(memeToken);
            token1 = address(weth);
            iswethToken0 = false;
        }

        // initialize pool
        PoolKey memory poolKey =
            PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), DEFAULT_FEE, 60, IHooks(unipump));
        poolManager.initialize(poolKey, Constants.SQRT_PRICE_1_1);

        emit TokenSaleCreated(
            address(memeToken), iswethToken0, _name, _symbol, _twitter, _discord, _bio, _imageUri, msg.sender
        );
        return address(memeToken);
    }
}
