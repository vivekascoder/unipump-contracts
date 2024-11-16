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

contract CreateSale is Script {
    IPoolManager poolManager = IPoolManager(0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829);
    IPositionManager posm = IPositionManager(0xcDbe7b1ed817eF0005ECe6a3e576fbAE2EA5EAFE);
    PoolSwapTest swapRouter = PoolSwapTest(0x96E3495b712c6589f1D2c50635FDE68CF17AC83c);
    PoolModifyLiquidityTest lpRouter = PoolModifyLiquidityTest(0xC94a4C0a89937E278a0d427bb393134E68d5ec09);
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    function run() public {
        // deploy the unipump creator contract
        MemeToken weth = MemeToken(0x79AE52Ca5f25199afDD381c2B835eFFC6Ead4a9a);

        vm.broadcast();
        weth.mint(msg.sender, 1_000_000 ether);
    }
}
