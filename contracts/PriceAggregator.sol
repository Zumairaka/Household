// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @notice creating a contract for retrieving the latest price
 * of the token
 */

contract PriceAggregator {
    /**
     * @dev using the function latestRoundData from AggregatorV3Interface
     * @param token address of the token of which we need
     * to fetch the latest data
     * @return price the price of the token in USD
     */

    function getLatestPrice(address token) external view returns (int256) {
        (, int256 price, , , ) = AggregatorV3Interface(token).latestRoundData();
        return price;
    }

    /**
     * @notice to return the decimals of the token
     * @dev use the decimals function in the aggregator contract
     * @param token address of the token of which we need
     * to fetch the latest data
     * @return decimals uint8
     */

    function decimals(address token) external view returns (uint8) {
        return AggregatorV3Interface(token).decimals();
    }
}
