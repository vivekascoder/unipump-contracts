// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {UD60x18, ud, exp, floor, sqrt} from "@prb/math/src/UD60x18.sol";

/// @title MathLib
/// @notice Extracted mathematical operations from UniPump
library MathLib {
    using {ud} for uint256;

    /// @notice Exponential curve function: 0.6015 * exp(0.00003606 * x)
    function curve(UD60x18 x) internal pure returns (UD60x18) {
        UD60x18 ex = exp(ud(0.00003606e18).mul(x));
        return ud(0.6015e18).mul(ex);
    }

    /// @notice Market cap: price * supply
    function cap(UD60x18 price, UD60x18 supply) internal pure returns (UD60x18) {
        return price.mul(supply);
    }

    /// @notice Price = market cap / M
    function priceFromCap(UD60x18 marketCap, UD60x18 M) internal pure returns (UD60x18) {
        return marketCap.div(M);
    }

    /// @notice Token out = weth_amount / current_price
    function tokenOutFromBuy(UD60x18 wethAmount, UD60x18 currentPrice) internal pure returns (UD60x18) {
        return wethAmount.div(currentPrice);
    }

    /// @notice WETH out = token_amount * current_price
    function wethOutFromSell(UD60x18 tokenAmount, UD60x18 currentPrice) internal pure returns (UD60x18) {
        return tokenAmount.mul(currentPrice);
    }

    /// @notice Compute sqrtPriceX96: floor(sqrt(price) * 2^96)
    function computeSqrtPrice(UD60x18 priceOf1Token) internal pure returns (UD60x18) {
        return floor(sqrt(priceOf1Token).mul(ud(2e18).pow(ud(96e18))));
    }

    /// @notice Compute dynamic beta: (random%19 + 1) / 100 + 1
    function computeBeta(uint256 randomNumber) internal pure returns (UD60x18) {
        UD60x18 beta = ud(((randomNumber % 19) + 1) * 1e18).div(ud(100e18)).add(ud(1e18));
        return beta;
    }

    /// @notice 95% of an amount
    function percent95(UD60x18 amount) internal pure returns (UD60x18) {
        return amount.mul(ud(0.95e18));
    }
}
