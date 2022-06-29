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
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

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
    address private _utilityToken;
    address private _utilityTokenPriceFeed;
    //address of priceAggregator
    PriceAggregator _priceAggregator;
    // object for the uniswap factory
    IUniswapV2Factory _uniswapFactory;
    // object for the uniswap router
    IUniswapV2Router02 _uinswapRouter;

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
    // modifier to check if an account is a member of the contract
    modifier onlyMember(address account) {
        require(_isMember[account] == true, "Household: not a member");
        _;
    }

    // modifer to check if the token already exists
    modifier tokenExists(address token) {
        address[] memory cryptos = _cryptoPortfolio;
        bool exists;

        for (uint256 i; i < cryptos.length; i++) {
            if (cryptos[i] == token) {
                exists = true;
                break;
            }
        }
        require(exists == false, "Household: token exists");
        _;
    }

    //modifier for checking the due date of the providers
    modifier checkDate(address provider) {
        require(
            IUtilityProvider(provider).getDueDate(address(this)) >=
                block.timestamp,
            "Household: duedate over"
        );
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
     * @dev initializer instead of constructor
     * @dev setting utility token and pricefeed
     * @dev setting both roles to the creator
     * @dev intializing creator as owner
     * @dev making the creator a member
     */
    function initialize(
        address priceAggregator_,
        address utilityToken_,
        address utilityTokenPriceFeed_,
        address uniswapRouter_,
        address uniswapFactory_
    ) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();

        _setupRole(SPECIAL_ROLE, _msgSender());
        _setupRole(ALLOWED_ROLE, _msgSender());
        _isMember[_msgSender()] = true;

        _priceAggregator = PriceAggregator(priceAggregator_);

        _utilityToken = utilityToken_;
        _utilityTokenPriceFeed = utilityTokenPriceFeed_;

        _uniswapFactory = IUniswapV2Factory(uniswapFactory_);
        _uinswapRouter = IUniswapV2Router02(uniswapRouter_);
    }

    /**
     * @notice function for registering to the utility providers
     * @dev calling a function using the {IUtilityProvider} interface
     * @param provider_ address of the utility providers
     * @param name_ unique string to know where you live
     * @return status gas provider reg status
     * following the same interface {IUtilityProvider}
     */
    function registerUtilities(address provider_, string memory name_)
        external
        onlyOwner
        returns (bool status)
    {
        status = IUtilityProvider(provider_).registerHousehold(
            address(this),
            name_
        );
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
     * @dev we need to create the pair for the uniswap market
     * with the token we are adding with the utility token
     * @param token_ address of the token to be added
     * @param priceFeed_ oracle for the token to be added
     */
    function addCrypto(address token_, address priceFeed_)
        external
        onlyRole(ALLOWED_ROLE)
        tokenExists(token_)
    {
        require(token_ != address(0), "Household: zero address");

        _cryptoPortfolio.push(token_);
        _priceFeeds.push(priceFeed_);

        // create pair with the utility token
        _uniswapFactory.createPair(token_, _utilityToken);

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
     * @dev role cannot change for the creator
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
        require(member_ != owner(), "Household: cannot change for creator");

        _revokeRole(role_, member_);
    }

    /**
     * @notice function for making payment to the utility providers
     * @dev allowed only for the allowed members
     * @dev we need to get the current rate of the token from the
     * oracle and convert to the utility token using uniswap swap function
     * @dev get the bill from the utility provider contract
     * @dev get the due date from the utility provider and check if the
     * date is over otherwise make the payment.
     * @dev this is not taking any parameters
     * @param provider_ address of the utility provider
     */
    function payTheBills(address provider_)
        external
        onlyRole(ALLOWED_ROLE)
        checkDate(provider_)
    {
        // get the bill for the providers
        uint256 amount = getTheBill(provider_);

        // get the latest rate for each token and use the lowest one
        // so that we can pay less amount as swapping fee
        (
            address paymentToken,
            int256 price,
            uint8 decimal
        ) = _getPaymentToken();

        // if the payment token is utility token itself then we
        // dont need to swap
        if (paymentToken == _utilityToken) {
            require(
                IERC20Upgradeable(_utilityToken).balanceOf(address(this)) >=
                    amount,
                "Household: insufficient balance"
            );

            // emit the event for making payment
            emit PaymentDone(provider_, amount);
            // transfer the bill to the utility provider
            IERC20Upgradeable(_utilityToken).safeTransfer(provider_, amount);
        } else {
            // we need to fetch the current price of the utility token
            // and find the equivalent amount of payment token
            int256 utilityPrice = _priceAggregator.getLatestPrice(
                _utilityTokenPriceFeed
            );
            uint256 paymentTokenAmount = (uint256(utilityPrice) *
                amount *
                uint256(decimal)) /
                (uint256(_priceAggregator.decimals(_utilityTokenPriceFeed)) *
                    uint256(price));
            // uniswap swapping fee is 0.3%. So we need to calculate the
            // fee and add this amount to the amountIn in uniswap swapping function
            uint256 amountIn = ((paymentTokenAmount * 3000) / 10**6) +
                paymentTokenAmount;

            // check for the balance of the portfolio for this token amount
            _checkBalance(paymentToken, amountIn, price, decimal);

            // call the uniswap swapping function
            uint256[] memory swappedAmounts = _getSwappedAmount(
                amount,
                amountIn,
                paymentToken
            );

            // emit the event for making payment
            emit PaymentDone(provider_, amount);

            // make the payment using swappedAmounts[1]
            IERC20Upgradeable(_utilityToken).safeTransfer(
                provider_,
                swappedAmounts[1]
            );
        }
    }

    /**
     * @notice this function is for changing the utility token address
     * @dev we need to change the price feed for the utility token also
     * @dev if the pricefeed is same as before no need to change
     * @dev or if the token is same and pricefeed has to change
     * @param token_ new address of the utility token address
     * @param priceFeed_ for the new token or new pricefeed of old token
     * nothin is returning. emitting an event {UtilityTokenChanged}
     */
    function changeUtilityPayment(address token_, address priceFeed_)
        external
        onlyOwner
    {
        require(
            token_ != _utilityToken || priceFeed_ != _utilityTokenPriceFeed,
            "Household: existing token"
        );
        _utilityToken = token_;
        _utilityTokenPriceFeed = priceFeed_;
    }

    /**
     * @notice function for retrieving the crypto portfolio and pricefeeds
     * @dev anyone can use this function
     * @dev no parameters
     * @return cryptoPortfolio array of portfolio
     * @return priceFeeds array of price feeds
     */
    function getCryptoPortfolio()
        external
        view
        returns (address[] memory cryptoPortfolio, address[] memory priceFeeds)
    {
        return (_cryptoPortfolio, _priceFeeds);
    }

    /**
     * @notice internal function for returning the bill amount
     * @dev internal function to call the provider interface and retrieve amount
     * @param provider provider address
     * @return amount the bill amount
     */
    function getTheBill(address provider) internal returns (uint256 amount) {
        amount = IUtilityProvider(provider).paymentRequired(address(this));
    }

    /**
     * @notice private function for fetching the latest price for each token
     * from the oracle and return the best token
     * @dev use different pricefeed for different tokens
     * @return paymentToken return the lowest priced token
     * @return price price of payment token in dollars
     * @return decimal decimals of the particular token
     */
    function _getPaymentToken()
        private
        view
        returns (
            address paymentToken,
            int256 price,
            uint8 decimal
        )
    {
        address[] memory cryptos = _cryptoPortfolio;
        address[] memory oracles = _priceFeeds;
        price = _priceAggregator.getLatestPrice(oracles[0]);

        for (uint256 i = 1; i < cryptos.length; i++) {
            int256 tokenPrice = _priceAggregator.getLatestPrice(oracles[i]);
            if (tokenPrice < price) {
                price = tokenPrice;
                paymentToken = cryptos[i];
                decimal = _priceAggregator.decimals(cryptos[i]);
            }
        }
    }

    /**
     * @notice private function for swapping the payment token wrt the utility token
     * @dev amountOut is utility token and amount of payment token is amountIn
     * @param amountOut utility token amount
     * @param amountIn payment token amount
     * @param paymentToken paymentToken address
     * @return swappedAmounts array of amountIn followed by amountOuts
     */
    function _getSwappedAmount(
        uint256 amountOut,
        uint256 amountIn,
        address paymentToken
    ) private returns (uint256[] memory swappedAmounts) {
        address[] memory path = new address[](2);
        path[0] = paymentToken;
        path[1] = _utilityToken;

        // approve to transfer the token to the uniswap
        IERC20Upgradeable(paymentToken).approve(
            address(_uinswapRouter),
            amountIn
        );
        swappedAmounts = _uinswapRouter.swapTokensForExactTokens(
            amountOut,
            amountIn,
            path,
            address(this),
            block.timestamp + 1 days
        );
    }

    /**
     * @notice function for checking the balance, if not enough balance
     * then revert otherwise will check for the remaining balance
     * @dev if the remaining balance is less than 50 dollar then it will
     * emit an event to inform the low balance
     * @param paymentToken token in which payment is done
     * @param payment number of tokens going to swap for
     * converting to utility token for making the payment
     * @param price price in dollar per token
     * @param decimal decimal of the token
     */

    function _checkBalance(
        address paymentToken,
        uint256 payment,
        int256 price,
        uint8 decimal
    ) private {
        uint256 balance = IERC20Upgradeable(paymentToken).balanceOf(
            address(this)
        );
        require(balance >= payment, "Household: low balance");

        // find the balance after deducting the payment
        balance -= payment;
        if ((balance * uint256(price)) / uint256(decimal) < 50) {
            emit LowBalance(paymentToken, balance);
        }
    }
}
