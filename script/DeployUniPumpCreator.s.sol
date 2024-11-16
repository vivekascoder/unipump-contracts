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
import "../src/DynamicFeeHook.sol";

contract DeployUniPumpCreator is Script {
    IPoolManager poolManager = IPoolManager(0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829);
    IPositionManager posm = IPositionManager(0xcDbe7b1ed817eF0005ECe6a3e576fbAE2EA5EAFE);
    PoolSwapTest swapRouter = PoolSwapTest(0x96E3495b712c6589f1D2c50635FDE68CF17AC83c);
    PoolModifyLiquidityTest lpRouter = PoolModifyLiquidityTest(0xC94a4C0a89937E278a0d427bb393134E68d5ec09);
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    address entropy = 0x41c9e39574F40Ad34c79f1C99B66A45eFB830d4c;
    address provider = 0x6CC14824Ea2918f5De5C2f75A9Da968ad4BD6344;
    address priceFeedContract = 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729;
    bytes32 priceFeedWethId = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;

    function run() public {
        // deploy mock weth
        vm.broadcast();
        MemeToken weth = new MemeToken("Unipump WETH Coin", "WETH", 18);

        vm.broadcast();
        weth.mint(msg.sender, 1_000_000 ether);

        // deploy the fee hook.
        uint160 permissions = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
                | Hooks.BEFORE_INITIALIZE_FLAG
        );

        uint160 feeHookPermissions =
            uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_INITIALIZE_FLAG);
        (address feeHookAddress, bytes32 feeeHookSalt) = HookMiner.find(
            CREATE2_DEPLOYER,
            feeHookPermissions,
            type(DynamicFeeHook).creationCode,
            abi.encode(address(poolManager), address(weth))
        );

        vm.broadcast();
        DynamicFeeHook feeHook = new DynamicFeeHook{salt: feeeHookSalt}(poolManager, address(weth));
        require(address(feeHook) == feeHookAddress, "UniPump: fee hook address mismatch");

        // deploy the unipump hook contract
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            permissions,
            type(UniPump).creationCode,
            abi.encode(
                address(poolManager),
                address(weth),
                CREATE2_DEPLOYER,
                address(feeHook),
                entropy,
                provider,
                priceFeedContract,
                priceFeedWethId
            )
        );
        vm.broadcast();
        UniPump unipump = new UniPump{salt: salt}(
            poolManager,
            address(weth),
            CREATE2_DEPLOYER,
            address(feeHook),
            entropy,
            provider,
            priceFeedContract,
            priceFeedWethId
        );
        require(address(unipump) == hookAddress, "CounterScript: hook address mismatch");

        // deploy the unipump creator contract
        vm.broadcast();
        UniPumpCreator creator = new UniPumpCreator(
            address(poolManager), address(weth), CREATE2_DEPLOYER, address(unipump), address(feeHook)
        );

        // top up
        vm.broadcast();
        payable(address(unipump)).transfer(0.0001 ether);

        // create a token sale
        // vm.broadcast();
        // address memeTokenAddress = creator.createTokenSale(
        //     "Go Go Go Token",
        //     "GOGOGO",
        //     "https://twitter.com/gogogotoken",
        //     "https://discord.gg/gogogotoken",
        //     "Go Go Go Token is the best token in the world",
        //     "https://placekitte.com/100/100"
        // );

        // buy token
        // vm.broadcast();
        // weth.approve(address(unipump), 0.01e18);
        // vm.broadcast();
        // unipump.buyTokenFromSale(address(weth), 0.01e18);

        // // sell token
        // vm.broadcast();
        // MemeToken(memeTokenAddress).approve(address(unipump), 0.01e18);
        // vm.broadcast();
        // unipump.sellTokenFromSale(memeTokenAddress, 0.01e18);

        console.log("UniPumpCreator: ", address(creator));
        console.log("UniPump: ", address(unipump));
        console.log("FeeHook: ", address(feeHook));
        console.log("weth: ", address(weth));
        // console.log("GOGOGO Token adddress: ", memeTokenAddress);
    }
}
