// Layout of Contract:
// license
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";

/**
 * @title DSCEngine
 * @author hsnyibrhm
 * the system is designed to be as minimal as possible, & have the tokens maintain a 1 token == $1 peg.
 * this stable coin has properties
 * - exogenous collateral
 * - dollar pegged
 * - algorithmically stable
 *
 * it is similar to DAI is DAI had no governance, no fees, and was backed by eth and btc only.
 *
 * this dsc system sould always be overcollateralized. at no point, should the value of the collateral <= the $ backed avalue of all the dsc.
 *
 * @notice this contract is the core of the dsc system. it handles all the logic for mining and redeeming DSC, as well as depositing & withdrawing collateral.
 * @notice this contract is veri loosely based on the makerdao DSS(DAI) system
 *
 */

contract DSCEngine {
    /**
     * errors
     */
    error DSCEngine__NeedsMoreCollateral();
    error DSCEngine__NotAllowedToMint();
    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine_TokenAddressAndPriceFeedAddressMustBeSameLength();

    /**
     * state variables
     */

    mapping(address token => address priceFeed) private s_priceFeeds;

    DecentralizedStableCoin private immutable i_dsc;

    /**
     * modifiers
     */
    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
        _;
    }

    // modifier isAllowedToken(address token) {
    //     // check if the token is allowed to be used as collateral
    //     if (!allowedTokens[token]) {
    //         revert DSCEngine__NotAllowedToMint();
    //     }
    //     _;
    // }

    /**
     * constructor
     */
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddress,
        address dscAddress
    ) {
        if (tokenAddresses.length != priceFeedAddress.length) {
            revert DSCEngine_TokenAddressAndPriceFeedAddressMustBeSameLength();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddress[i];
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    /**
     * function
     */

    /**
     * external functions
     */
    function depositCollateralAndMintDsc() external payable {}

    /**
     *
     * @param tokenCollateralAddress the address of the token to deposit as collateral
     * @param amountCollateral the amount of collareral to deposit
     */
    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) external moreThanZero(amountCollateral) {
        // 1. transfer collateral to this contract
        // 2. update the users collateral balance
    }

    function redeemCollateralForDsc() external payable {}

    function redeemCollateral() external {}

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view returns (uint256) {}
}
