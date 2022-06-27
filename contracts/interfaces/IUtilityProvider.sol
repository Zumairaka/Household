// SPDX-License-Provider: MIT
pragma solidity ^0.8.0;

/**
 * interface for the utility provider contract
 */

interface IUtilityProvider {
    /**
     * @notice function for registering the household
     * @param household address of the household contract
     * @param name is a unique string that allows utility provider to know where you live.
     * @return status status of the registration
     */
    function registerHousehold(address household, string memory name)
        external
        returns (bool);

    /**
     * @notice function for retrieving the bill amount
     * @dev the bill amount is in number of utility tokens
     * @param household address of the household contract
     * @return amount returns the amount of stable coin that needs to be paid
     */
    function paymentRequired(address household) external returns (uint256);
}
