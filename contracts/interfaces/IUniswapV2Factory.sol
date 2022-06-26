// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @notice creating an interface for uniswap factory
 * for creating a pair with the token and utility
 * provider's stable coin
 * deployed at '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f'
 * on the Ethereum mainnet, and the Ropsten, Rinkeby, Görli, and Kovan testnets.
 */

interface IUniswapV2Factory {
    /**
     * @dev this function is used to create a pair
     */
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}
