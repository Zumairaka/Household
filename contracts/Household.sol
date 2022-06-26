// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @author Sumaira K A
 * @notice This contract is for making automatic payment
 * to the utility providers such as gas, electricity and water
 * payment is accepted only on one stable coin; but the household
 * member has the choice to choose one of the crypto currency
 * from their cryptocurrency portpolio which is held inside the contract
 */

contract Household {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    
    // crypto currencies added by the household members
    address[] public cryptoPortfolio;
    // pricefeed oracle address for each crypto
    address[] public priceFeeds;
}
