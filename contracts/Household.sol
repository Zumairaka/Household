// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PriceAggregator.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUtilityProvider.sol";
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

contract Household is
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    OwnableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // STATE VARIABLES
    // crypto currencies added by the household members
    address[] private _cryptoPortfolio;
    // pricefeed oracle address for each crypto
    address[] private _priceFeeds;
    // stable coin supported by the utility provider
    address private _utilityTokenAddress;
    IERC20Upgradeable private _utilityToken;
    // address of gas utility provider
    address private _gasProviderAddress;
    IUtilityProvider private _gasProvider;
    // address of water utility provider
    address private _waterProviderAddress;
    IUtilityProvider private _waterProvider;
    // address of electricity utility provider
    address private _electricityProviderAddress;
    IUtilityProvider private _electricityProvider;
    //address of priceAggregator
    PriceAggregator private _priceAggregator;

    // EVENTS
    // event for informing the low balance of the token
    event LowBalance(address indexed token, uint256 balance);
    // event for informing the bill payment
    event PaymentDone(address indexed provider, uint256 amount);
    // event for informing addition of a new member
    event MemberAdded(address indexed member);
    // event for informing removal of a member
    event MemberRemoved(address indexed member, address indexed remover);
    // event for informing addition of a new crypto to the portfolio
    event CryptoAdded(
        address indexed token,
        address indexed priceFeed,
        address indexed member
    );
    // event for informing removal of a crypto from the portfolio
    event CryptoRemoved(
        address indexed token,
        address indexed priceFeed,
        address indexed member
    );

    // MODIFIERS
    modifier onlyMember(address account) {
        require(_isMember[account] == true, "Household: not a member");
        _;
    }

    // MAPPINGS
    // mapping for checking the house hold member
    mapping(address => bool) private _isMember;

    // ACCESS ROLES
    // special role
    bytes32 private constant SPECIAL_ROLE = keccak256("SPECIAL_ROLE");
    // allowed roles
    bytes32 private constant ALLOWED_ROLE = keccak256("ALLOWED_ROLE");

    /**
     * initializer instead of constructor
     * setting all the utility providers
     * setting both roles to the creator
     * intializing creator as owner
     * making the creator a member
     * setting price aggregator
     * setting utility token
     */
    function initialize(
        address gasProvider_,
        address waterProvider_,
        address electricityProvider_,
        address priceAggregator_,
        address utilityToken_
    ) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();

        _setupRole(SPECIAL_ROLE, _msgSender());
        _setupRole(ALLOWED_ROLE, _msgSender());
        _isMember[_msgSender()] = true;

        _gasProviderAddress = gasProvider_;
        _gasProvider = IUtilityProvider(gasProvider_);

        _waterProviderAddress = waterProvider_;
        _waterProvider = IUtilityProvider(waterProvider_);

        _electricityProviderAddress = electricityProvider_;
        _electricityProvider = IUtilityProvider(electricityProvider_);

        _priceAggregator = PriceAggregator(priceAggregator_);

        _utilityTokenAddress = utilityToken_;
        _utilityToken = IERC20Upgradeable(utilityToken_);
    }

    /**
     * @notice function for registering to the utility providers
     * @dev registering to each providers separately but they are
     * @param name_ unique string to know where you live
     * @return greg gas provider reg status
     * @return wreg water provider reg status
     * @return ereg electricity provider reg status
     * following the same interface {IUtilityProvider}
     */
    function registerUtilities(string memory name_)
        external
        onlyOwner
        returns (
            bool greg,
            bool wreg,
            bool ereg
        )
    {
        greg = _gasProvider.registerHousehold(address(this), name_);
        wreg = _waterProvider.registerHousehold(address(this), name_);
        ereg = _electricityProvider.registerHousehold(address(this), name_);
    }

    /**
     * @notice function for adding new members
     * @dev any member can add new members
     * @param member_ address of the account which has to be a member
     */
    function addMember(address member_) external onlyMember(_msgSender()) {
        require(_isMember[member_] == false, "Household: already member");

        _isMember[member_] = true;
        emit MemberAdded(member_);
    }

    /**
     * @notice function for removing a member
     * @dev only special member can remove a member including special member
     * @dev creator cannot be removed
     * @param member_ address of the account which has to be a member
     */
    function removeMember(address member_) external onlyRole(SPECIAL_ROLE) {
        require(member_ != owner(), "Household: creator cannot be removed");

        _isMember[member_] = false;
        emit MemberRemoved(member_, _msgSender());
    }

    /**
     * @notice function for adding crypto currency to the portfolio
     * @dev only allowed member can do this
     * @param token_ address of the token to be added
     * @param priceFeed_ oracle for the token to be added
     */
    function addCrypto(address token_, address priceFeed_)
        external
        onlyRole(ALLOWED_ROLE)
    {
        require(token_ != address(0), "Household: zero address");

        _cryptoPortfolio.push(token_);
        _priceFeeds.push(priceFeed_);
        emit CryptoAdded(token_, priceFeed_, _msgSender());
    }

    /**
     * @notice function for removing crypto currency from the portfolio
     * @dev only allowed member can do this
     * @dev we need to remove a token from the portfolio and resize the array
     * @param tokenIndex_ address of the token to be removed
     */
    function removeCrypto(uint8 tokenIndex_) external onlyRole(ALLOWED_ROLE) {
        require(
            tokenIndex_ <= _cryptoPortfolio.length - 1,
            "Household: invalid index"
        );
        address[] memory cryptos = _cryptoPortfolio;
        address[] memory oracles = _priceFeeds;
        address token = cryptos[tokenIndex_];
        address priceFeed = oracles[tokenIndex_];

        cryptos[tokenIndex_] = cryptos[cryptos.length - 1];
        delete cryptos[cryptos.length - 1];

        oracles[tokenIndex_] = oracles[oracles.length - 1];
        delete oracles[oracles.length - 1];

        _cryptoPortfolio = cryptos;
        _priceFeeds = oracles;
        emit CryptoRemoved(token, priceFeed, _msgSender());
    }

    /**
     * @notice function for setting the role to the members
     * @dev only creator can set role to the members
     * @param member_ address of the member to allocate a role
     * @param role_ role to be allocated
     */
    function allocateRole(address member_, bytes32 role_)
        external
        onlyOwner
        onlyMember(member_)
    {
        require(
            role_ == SPECIAL_ROLE || role_ == ALLOWED_ROLE,
            "Household: invalid role"
        );
        _grantRole(role_, member_);
    }

    /**
     * @notice function for revoking the role of a member
     * @dev only creator can revoke role of a member
     * @param member_ address of the member to allocate a role
     * @param role_ role to be allocated
     */
    function deAllocateRole(address member_, bytes32 role_)
        external
        onlyOwner
        onlyMember(member_)
    {
        require(
            role_ == SPECIAL_ROLE || role_ == ALLOWED_ROLE,
            "Household: invalid role"
        );
        _revokeRole(role_, member_);
    }
}
