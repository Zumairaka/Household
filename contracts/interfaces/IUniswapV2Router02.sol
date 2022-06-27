// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @notice creating an interface for uniswap
 * for swapping the token with the stable coin for
 * the utility payment
 * UniswapV2Router02 is deployed at 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
 * on the Ethereum mainnet, and the Ropsten, Rinkeby, Görli, and Kovan testnets.
 */

interface IUniswapV2Router02 {
    /**
     * @notice this function is used to swap
     */
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}
